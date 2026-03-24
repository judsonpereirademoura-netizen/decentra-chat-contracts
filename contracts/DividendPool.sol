// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol"; // [F-14]
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @dev Interface para consultar o endereço do contrato DGovToken [F-15]
 */
interface IDGovTokenForDividend {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getVestingWeight(address holder) external view returns (uint256); // [F-17]
    function founder() external view returns (address); // [F-17]
    function totalMarketingLocked() external view returns (uint256); // [SA-05] Usar locked, não distributed
    function FOUNDER_ALLOCATION() external view returns (uint256); // [F-17]
}

/**
 * @title DividendPool v2.0
 * @author DecentraChat Protocol
 * @notice Pool de dividendos que distribui receita da plataforma para holders de $DGOV.
 *
 *   FONTES DE RECEITA:
 *     1. 20% de cada mensagem processada (via DChatStablecoin)
 *     2. 100% dos $DCHAT arrecadados nos leilões de $DGOV (via DGovToken)
 *
 *   DISTRIBUIÇÃO:
 *     - Proporcional ao "peso de dividendo" de cada holder
 *     - Tokens em vesting (founder 30M + marketing 10M) contam para dividendos desde dia 1
 *     - Peso = balanceOf(holder) + vestingWeight(holder)
 *     - Sistema de pontos-por-token para distribuição eficiente sem loops
 *
 *   ELEGIBILIDADE:
 *     - Qualquer endereço que possua $DGOV (em carteira ou em vesting)
 *     - Founder: 30M de peso desde dia 1 (mesmo antes do unlock)
 *     - Marketing: 10M de peso desde dia 1 (mesmo antes do unlock)
 *     - Compradores de leilão: peso = saldo na carteira
 */
contract DividendPool is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    // =========================================================================
    // ROLES [F-16]
    // =========================================================================
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    // =========================================================================
    // INTERFACES
    // =========================================================================
    IERC20 public dchatToken;   // $DCHAT stablecoin
    IDGovTokenForDividend public dgovToken; // $DGOV governance token
    address public dgovTokenAddress; // [F-15] Endereço do contrato DGovToken para descontar tokens inativos

    // =========================================================================
    // DIVIDEND TRACKING (Points-per-token system)
    // =========================================================================
    uint256 public constant PRECISION = 1e36;

    uint256 public totalDividendsDeposited;
    uint256 public totalDividendsClaimed;
    uint256 public pointsPerToken;  // Accumulated points per $DGOV token

    mapping(address => uint256) public lastPointsPerToken;  // Snapshot per user
    mapping(address => uint256) public pendingDividends;     // Unclaimed dividends
    mapping(address => uint256) public totalClaimedByUser;   // Historical claims

    // =========================================================================
    // TOTAL DIVIDEND WEIGHT
    // =========================================================================
    // totalDividendWeight = circulatingSupply($DGOV) + founderAutoWeight + marketingAutoWeight
    // Vesting weight is now calculated automatically via DGovToken.getVestingWeight()

    // =========================================================================
    // REVENUE SOURCES TRACKING
    // =========================================================================
    uint256 public totalFromMessaging;   // 20% das taxas de mensagem
    uint256 public totalFromAuctions;    // 100% da receita dos leilões
    uint256 public deployedAt;           // [F-18] Timestamp de deploy para yield calculation

    // =========================================================================
    // EVENTS
    // =========================================================================
    event DividendsDeposited(uint256 amount, uint256 newPointsPerToken, uint256 timestamp, string source);
    event DividendsClaimed(address indexed holder, uint256 amount, uint256 timestamp);
    event DividendsUpdated(address indexed holder, uint256 newPending);
    event VestingWeightSet(address indexed holder, uint256 oldWeight, uint256 newWeight);

    // =========================================================================
    // CONSTRUCTOR / INITIALIZER
    // =========================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _dchatToken, address _dgovToken, address _admin) initializer public {
        require(_dchatToken != address(0), "Invalid DCHAT");
        require(_dgovToken != address(0), "Invalid DGOV");
        require(_admin != address(0), "Invalid admin");

        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        dchatToken = IERC20(_dchatToken);
        dgovToken = IDGovTokenForDividend(_dgovToken);
        dgovTokenAddress = _dgovToken; // [F-15]
        deployedAt = block.timestamp; // [F-18]

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(DEPOSITOR_ROLE, _admin); // [F-16] Admin can deposit initially
    }

    // =========================================================================
    // UUPS UPGRADE AUTHORIZATION
    // =========================================================================

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // =========================================================================
    // DEPOSIT DIVIDENDS
    // =========================================================================

    /**
     * @notice Deposit $DCHAT dividends from messaging fees (20% of each message).
     */
    function depositDividends(uint256 amount) external onlyRole(DEPOSITOR_ROLE) whenNotPaused { // [F-16]
        _depositInternal(amount, "messaging");
        totalFromMessaging += amount;
    }

    /**
     * @notice Deposit $DCHAT dividends from auction revenue (100% of auction proceeds).
     */
    function depositAuctionRevenue(uint256 amount) external onlyRole(DEPOSITOR_ROLE) { // [F-16]
        _depositInternal(amount, "auction");
        totalFromAuctions += amount;
    }

    /**
     * @notice [AUTO-03] Notifica o DividendPool que tokens foram depositados via transfer direto.
     *         Chamada automaticamente pelo DGovToken.finalizeAuction após transferir receita.
     *         Não faz transferFrom — os tokens já estão no contrato.
     * @param amount Quantidade de $DCHAT já transferida para este contrato
     */
    function notifyAuctionDeposit(uint256 amount) external {
        require(msg.sender == dgovTokenAddress, "Only DGovToken"); // [AUTO-03] Só o DGovToken pode notificar
        require(amount > 0, "Amount must be > 0");

        uint256 totalWeight = _getTotalDividendWeight();
        if (totalWeight > 0) {
            pointsPerToken += (amount * PRECISION) / totalWeight;
        }

        totalDividendsDeposited += amount;
        totalFromAuctions += amount;

        emit DividendsDeposited(amount, pointsPerToken, block.timestamp, "auction-auto");
    }

    function _depositInternal(uint256 amount, string memory source) internal {
        require(amount > 0, "Amount must be > 0");

        // Transfer $DCHAT from sender to this contract
        dchatToken.safeTransferFrom(msg.sender, address(this), amount);

        uint256 totalWeight = _getTotalDividendWeight();
        if (totalWeight > 0) {
            pointsPerToken += (amount * PRECISION) / totalWeight;
        }

        totalDividendsDeposited += amount;

        emit DividendsDeposited(amount, pointsPerToken, block.timestamp, source);
    }

    // =========================================================================
    // CLAIM DIVIDENDS
    // =========================================================================

    /**
     * @notice Claim pending dividends for the caller.
     */
    function claimDividends() external nonReentrant whenNotPaused {
        _updateDividends(msg.sender);

        uint256 amount = pendingDividends[msg.sender];
        require(amount > 0, "No dividends to claim");

        pendingDividends[msg.sender] = 0;
        totalDividendsClaimed += amount;
        totalClaimedByUser[msg.sender] += amount;

        dchatToken.safeTransfer(msg.sender, amount);

        emit DividendsClaimed(msg.sender, amount, block.timestamp);
    }

    // =========================================================================
    // [F-14] CIRCUIT BREAKER
    // =========================================================================

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    /**
     * @notice Get the effective dividend weight for a holder.
     * @dev Weight = balanceOf($DGOV) + vestingWeight
     */
    /**
     * @dev [F-17] Consulta automaticamente o DGovToken.getVestingWeight()
     *      para calcular o peso de dividendo do holder.
     */
    function getHolderWeight(address holder) public view returns (uint256) {
        uint256 balance = dgovToken.balanceOf(holder);
        uint256 autoWeight = dgovToken.getVestingWeight(holder);
        return balance + autoWeight;
    }

    /**
     * @notice Get the total dividend weight across all holders.
     */
    function _getTotalDividendWeight() internal view returns (uint256) {
        // [F-15] Descontar tokens inativos no contrato DGovToken
        // [F-17] Calcula vesting weight automático:
        //   - Founder: FOUNDER_ALLOCATION - tokens já claimed (via getVestingWeight)
        //   - Marketing: totalMarketingLocked (tokens locked com prestadores)
        // Fórmula: circulatingSupply + founderAutoWeight + marketingAutoWeight
        uint256 circulatingSupply = dgovToken.totalSupply() - dgovToken.balanceOf(dgovTokenAddress);

        // Calcular vesting weight automático total
        // Founder vesting weight
        uint256 founderAutoWeight = dgovToken.getVestingWeight(dgovToken.founder());
        // [SA-05] Marketing: APENAS tokens ainda locked (não os já unlocked que estão no balanceOf)
        uint256 marketingAutoWeight = dgovToken.totalMarketingLocked();
        return circulatingSupply + founderAutoWeight + marketingAutoWeight;
    }

    function getTotalDividendWeight() external view returns (uint256) {
        return _getTotalDividendWeight();
    }

    /**
     * @notice Get the pending dividends for a holder.
     */
    function getPendingDividends(address holder) external view returns (uint256) {
        uint256 holderWeight = getHolderWeight(holder);
        if (holderWeight == 0) return pendingDividends[holder];

        uint256 newPoints = pointsPerToken - lastPointsPerToken[holder];
        uint256 owed = (holderWeight * newPoints) / PRECISION;
        return pendingDividends[holder] + owed;
    }

    /**
     * @notice Get pool statistics.
     */
    function getPoolStats() external view returns (
        uint256 _totalDeposited,
        uint256 _totalClaimed,
        uint256 _poolBalance,
        uint256 _pointsPerToken,
        uint256 _totalFromMessaging,
        uint256 _totalFromAuctions,
        uint256 _totalDividendWeight
    ) {
        return (
            totalDividendsDeposited,
            totalDividendsClaimed,
            dchatToken.balanceOf(address(this)),
            pointsPerToken,
            totalFromMessaging,
            totalFromAuctions,
            _getTotalDividendWeight()
        );
    }

    /**
     * @notice Get holder-specific dividend info.
     */
    function getHolderInfo(address holder) external view returns (
        uint256 holderWeight,
        uint256 dgovBalance,
        uint256 vWeight,
        uint256 pending,
        uint256 totalClaimed,
        uint256 sharePercentage  // basis points (10000 = 100%)
    ) {
        holderWeight = getHolderWeight(holder);
        dgovBalance = dgovToken.balanceOf(holder);
        vWeight = dgovToken.getVestingWeight(holder);

        // Calculate pending
        uint256 newPoints = pointsPerToken - lastPointsPerToken[holder];
        uint256 owed = (holderWeight * newPoints) / PRECISION;
        pending = pendingDividends[holder] + owed;

        totalClaimed = totalClaimedByUser[holder];

        uint256 totalWeight = _getTotalDividendWeight();
        if (totalWeight > 0) {
            sharePercentage = (holderWeight * 10000) / totalWeight;
        }
    }

    /**
     * @notice Estimate annual yield for a given weight.
     */
    function estimateAnnualYield(uint256 weight) external view returns (uint256) {
        uint256 totalWeight = _getTotalDividendWeight();
        if (totalWeight == 0 || totalDividendsDeposited == 0) return 0;

        // [F-18] Usar tempo real ao invés de hardcoded 30 dias
        uint256 elapsed = block.timestamp - deployedAt;
        if (elapsed < 1 days) elapsed = 1 days; // Mínimo 1 dia para evitar divisão por zero

        uint256 shareRatio = (weight * PRECISION) / totalWeight;
        uint256 holderShare = (totalDividendsDeposited * shareRatio) / PRECISION;
        return (holderShare * 365 days) / elapsed;
    }

    // =========================================================================
    // INTERNAL
    // =========================================================================

    function _updateDividends(address holder) internal {
        uint256 holderWeight = getHolderWeight(holder);

        if (holderWeight > 0) {
            uint256 newPoints = pointsPerToken - lastPointsPerToken[holder];
            uint256 owed = (holderWeight * newPoints) / PRECISION;
            pendingDividends[holder] += owed;

            emit DividendsUpdated(holder, pendingDividends[holder]);
        }

        lastPointsPerToken[holder] = pointsPerToken;
    }
}
