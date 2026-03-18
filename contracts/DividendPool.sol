// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol"; // [F-14]

/**
 * @dev Interface para consultar o endereço do contrato DGovToken [F-15]
 */
interface IDGovTokenForDividend {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
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
contract DividendPool is AccessControl, ReentrancyGuard, Pausable {

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
    // VESTING WEIGHT — Tokens em vesting contam para dividendos
    // =========================================================================
    // O founder e marketing recebem dividendos sobre seus 30M e 10M respectivamente,
    // mesmo antes do unlock. O admin registra esses pesos fixos.
    mapping(address => uint256) public vestingWeight;
    uint256 public totalVestingWeight;

    // =========================================================================
    // TOTAL DIVIDEND WEIGHT
    // =========================================================================
    // totalDividendWeight = totalSupply($DGOV) + totalVestingWeight
    // (tokens em vesting estão no contrato DGovToken, não na carteira dos beneficiários,
    //  então precisamos somar o vestingWeight separadamente)

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
    // CONSTRUCTOR
    // =========================================================================
    constructor(
        address _dchatToken,
        address _dgovToken,
        address _admin
    ) {
        require(_dchatToken != address(0), "Invalid DCHAT");
        require(_dgovToken != address(0), "Invalid DGOV");
        require(_admin != address(0), "Invalid admin");

        dchatToken = IERC20(_dchatToken);
        dgovToken = IDGovTokenForDividend(_dgovToken);
        dgovTokenAddress = _dgovToken; // [F-15]
        deployedAt = block.timestamp; // [F-18]

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(DEPOSITOR_ROLE, _admin); // [F-16] Admin can deposit initially
    }

    // =========================================================================
    // VESTING WEIGHT MANAGEMENT
    // =========================================================================

    /**
     * @notice Set vesting weight for an address (founder/marketing).
     * @dev Tokens em vesting contam para dividendos desde dia 1.
     *      Quando o vesting é liberado (tokens transferidos para a carteira),
     *      o admin deve reduzir o vestingWeight correspondente.
     */
    function setVestingWeight(address holder, uint256 weight) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(holder != address(0), "Invalid holder");

        // Update dividends before changing weight
        _updateDividends(holder);

        uint256 oldWeight = vestingWeight[holder];
        totalVestingWeight = totalVestingWeight - oldWeight + weight;
        vestingWeight[holder] = weight;

        emit VestingWeightSet(holder, oldWeight, weight);
    }

    /**
     * @notice Reduce vesting weight when tokens are unlocked (claimed from vesting).
     * @dev Called by admin when founder/marketing claims a vesting tranche.
     */
    function reduceVestingWeight(address holder, uint256 reduction) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(holder != address(0), "Invalid holder");
        require(reduction <= vestingWeight[holder], "Reduction exceeds weight");

        _updateDividends(holder);

        uint256 oldWeight = vestingWeight[holder];
        vestingWeight[holder] -= reduction;
        totalVestingWeight -= reduction;

        emit VestingWeightSet(holder, oldWeight, vestingWeight[holder]);
    }

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

    function _depositInternal(uint256 amount, string memory source) internal {
        require(amount > 0, "Amount must be > 0");

        // Transfer $DCHAT from sender to this contract
        require(
            dchatToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

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

        require(
            dchatToken.transfer(msg.sender, amount),
            "Transfer failed"
        );

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
    function getHolderWeight(address holder) public view returns (uint256) {
        return dgovToken.balanceOf(holder) + vestingWeight[holder];
    }

    /**
     * @notice Get the total dividend weight across all holders.
     */
    function _getTotalDividendWeight() internal view returns (uint256) {
        // [F-15] CORRIGIDO: Descontar tokens inativos no contrato DGovToken
        // O contrato DGovToken segura: auction tokens + unvested founder/marketing tokens
        // Auction tokens NÃO devem contar para dividendos (nunca podem claim)
        // Unvested tokens contam via vestingWeight separadamente
        // Fórmula: (totalSupply - balanceOf(DGovToken_contract)) + totalVestingWeight
        // Isso dá: tokens em circulação real + peso de vesting
        uint256 circulatingSupply = dgovToken.totalSupply() - dgovToken.balanceOf(dgovTokenAddress);
        return circulatingSupply + totalVestingWeight;
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
        vWeight = vestingWeight[holder];

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
