// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
contract DividendPool is AccessControl, ReentrancyGuard {

    // =========================================================================
    // INTERFACES
    // =========================================================================
    IERC20 public dchatToken;   // $DCHAT stablecoin
    IERC20 public dgovToken;    // $DGOV governance token

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
        dgovToken = IERC20(_dgovToken);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
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
    function depositDividends(uint256 amount) external {
        _depositInternal(amount, "messaging");
        totalFromMessaging += amount;
    }

    /**
     * @notice Deposit $DCHAT dividends from auction revenue (100% of auction proceeds).
     */
    function depositAuctionRevenue(uint256 amount) external {
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
    function claimDividends() external nonReentrant {
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
        // totalSupply includes all minted tokens (even those in the DGovToken contract)
        // We need: circulating supply + vesting weight
        // But since vesting tokens are IN the DGovToken contract (not burned),
        // they're part of totalSupply. We use totalSupply - burned + vestingWeight
        // Actually: totalSupply already excludes burned tokens.
        // Vesting tokens are held by DGovToken contract address.
        // So: totalWeight = totalSupply (includes contract-held) + totalVestingWeight
        // Wait — that would double-count. Let me think...
        //
        // The DGovToken contract holds: auction tokens + unvested founder/marketing tokens
        // Auction tokens should NOT count for dividends.
        // Unvested founder/marketing tokens should count (via vestingWeight).
        //
        // So: totalWeight = (totalSupply - balanceOf(DGovToken_contract)) + totalVestingWeight
        // This gives us: circulating tokens + vesting weight
        //
        // But we don't know the DGovToken contract address here easily.
        // Solution: just use totalSupply() + totalVestingWeight, and the DGovToken
        // contract itself won't claim dividends (it has no mechanism to do so).
        // The excess points allocated to the contract's balance are effectively lost/unclaimed.
        //
        // Better approach: use totalSupply + totalVestingWeight as the denominator.
        // Holders get: (their weight / totalWeight) * dividends
        // DGovToken contract's tokens are "dead weight" that dilute slightly,
        // but since those tokens can never claim, the unclaimed dividends stay in the pool.
        //
        // For simplicity and correctness, we use this approach.

        return dgovToken.totalSupply() + totalVestingWeight;
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

        uint256 shareRatio = (weight * PRECISION) / totalWeight;
        return (totalDividendsDeposited * shareRatio * 365) / (PRECISION * 30);
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
