// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// [AUTO-03] Interface para notificar DividendPool automaticamente
interface IDividendPool {
    function notifyAuctionDeposit(uint256 amount) external;
}

/**
 * @title DGovToken ($DGOV) v6.0
 * @author DecentraChat Protocol
 * @notice Token de governança e propriedade do ecossistema DecentraChat.
 *         UUPS Proxy Upgradeable.
 *
 *   ALOCAÇÃO DO SUPPLY (100M):
 *     - 30% Fundador (30M) — vesting 10M a cada 12 meses, recebe dividendos desde dia 1
 *     - 10% Marketing (10M) — liberado ao fundador, lock 180 dias por transferência a prestadores
 *     - 60% Leilões (60M) — 156 leilões semanais fracionados, início T+90 dias
 *
 *   Audit v3 fixes: C-03, H-03, M-06
 */
contract DGovToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // =========================================================================
    // CONSTANTS
    // =========================================================================
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 1e18;
    uint256 public constant FOUNDER_ALLOCATION = 30_000_000 * 1e18;
    uint256 public constant MARKETING_ALLOCATION = 10_000_000 * 1e18;
    uint256 public constant AUCTION_ALLOCATION = 60_000_000 * 1e18;

    uint256 public constant TOTAL_AUCTIONS = 156;
    uint256 public constant AUCTION_DURATION = 24 hours;
    uint256 public constant AUCTION_INTERVAL = 7 days;
    uint256 public constant AUCTION_DELAY = 90 days;
    uint256 public constant WARMUP_PERIOD = 2 hours;
    uint256 public constant ANTI_SNIPE_WINDOW = 10 minutes;
    uint256 public constant ANTI_SNIPE_EXTENSION = 10 minutes;

    uint256 public constant MIN_BID_PER_DGOV = 1e16; // 0.01 $DCHAT por $DGOV
    uint256 public constant MIN_INCREMENT_BPS = 500;  // 5% incremento mínimo
    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public constant MAX_BIDS_PER_AUCTION = 50;  // [C-03] Reduzido de 100→50 para evitar DoS por gas no sorting O(n²)
    uint256 public constant MAX_ANTI_SNIPE_EXTENSIONS = 6; // [F-03] Máximo 1h extra

    uint256 public constant VESTING_TRANCHES = 3;
    uint256 public constant VESTING_INTERVAL = 365 days;
    uint256 public constant FOUNDER_PER_TRANCHE = 10_000_000 * 1e18;

    uint256 public constant MARKETING_LOCK_PERIOD = 180 days;
    uint256 public constant MARKETING_VESTING_PERIOD = 180 days;

    uint256 public constant AUCTIONS_PER_PHASE = 26;

    // =========================================================================
    // ROLES
    // =========================================================================
    bytes32 public constant AUCTION_MANAGER_ROLE = keccak256("AUCTION_MANAGER_ROLE");

    // =========================================================================
    // STATE — ADDRESSES
    // =========================================================================
    address public founder;
    address public dchatToken;
    address public dividendPool;

    // =========================================================================
    // STATE — VESTING
    // =========================================================================
    uint256 public vestingStart;
    uint256 public founderTranchesClaimed;

    struct MarketingLock {
        uint256 amount;
        uint256 lockEnd;
        uint256 vestingEnd;
        uint256 claimed;
    }
    mapping(address => MarketingLock[]) public marketingLocks;
    mapping(address => uint256) public marketingLockedCache;
    uint256 public totalMarketingDistributed;
    uint256 public totalMarketingLocked;

    // =========================================================================
    // STATE — REGISTERED USERS
    // =========================================================================
    mapping(address => bool) public registeredUsers;
    uint256 public totalRegisteredUsers;

    // =========================================================================
    // STATE — ESCROW POOL
    // =========================================================================
    struct EscrowBalance {
        uint256 total;
        uint256 locked;
    }

    mapping(address => EscrowBalance) public escrowBalances;
    uint256 public totalEscrowBalance;

    // =========================================================================
    // STATE — FRACTIONAL AUCTION
    // =========================================================================
    struct Bid {
        address bidder;
        uint256 quantity;
        uint256 pricePerUnit;
        uint256 totalCost;
        bool filled;
        uint256 filledQty;
        bool refunded;
    }

    struct Auction {
        uint256 id;
        uint256 tokensAvailable;
        uint256 startTime;
        uint256 endTime;
        uint256 highestPricePerUnit;
        uint256 totalBidCount;
        uint256 totalBidVolume;
        bool finalized;
        bool tokensBurned;
        uint256 totalRevenue;
        uint256 tokensSold;
        uint256 tokensBurnedAmount;
        uint256 antiSnipeCount;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids;
    mapping(uint256 => mapping(address => uint256[])) public userBidIndices;

    uint256 public currentAuctionId;
    uint256 public auctionsStartTime;
    uint256 public totalTokensBurned;
    uint256 public totalAuctionRevenue;

    address public governanceContract;

    // Distribuição progressiva por fase
    // Fase 1: 7%, Fase 2: 14%, Fase 3: 21.5%, Fase 4: 21.5%, Fase 5: 18%, Fase 6: 18%
    uint256[6] private _phasePercentages;

    // =========================================================================
    // EVENTS
    // =========================================================================
    event VestingClaimed(address indexed beneficiary, string vestingType, uint256 tranche, uint256 amount);
    event MarketingTokensTransferred(address indexed recipient, uint256 amount, uint256 unlockTime, uint256 lockIndex);
    event MarketingTokensUnlocked(address indexed recipient, uint256 lockIndex, uint256 amount);
    event UserRegistered(address indexed user);
    event UserUnregistered(address indexed user);

    event EscrowDeposited(address indexed user, uint256 amount, uint256 totalBalance);
    event EscrowWithdrawn(address indexed user, uint256 amount, uint256 remainingBalance);

    event AuctionStarted(uint256 indexed auctionId, uint256 tokensAvailable, uint256 startTime, uint256 endTime);
    event AuctionExtended(uint256 indexed auctionId, uint256 newEndTime);
    event BidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 quantity, uint256 pricePerUnit, uint256 totalCost, uint256 bidIndex);
    event AuctionFinalized(uint256 indexed auctionId, uint256 tokensSold, uint256 tokensBurned, uint256 totalRevenue, uint256 totalBids);
    event BidFilled(uint256 indexed auctionId, address indexed bidder, uint256 bidIndex, uint256 filledQty, uint256 cost);
    event BidRefunded(uint256 indexed auctionId, address indexed bidder, uint256 bidIndex, uint256 refundAmount);
    event TokensBurned(uint256 indexed auctionId, uint256 amount);
    event DividendsSent(uint256 indexed auctionId, uint256 amount);

    event GovernanceContractSet(address indexed governanceContract);
    event DividendPoolUpdated(address indexed oldPool, address indexed newPool);

    // =========================================================================
    // CONSTRUCTOR & INITIALIZER
    // =========================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _founder,
        address _dchatToken,
        address _dividendPool
    ) initializer public {
        require(_founder != address(0), "Invalid founder");
        require(_dchatToken != address(0), "Invalid DCHAT token");
        require(_dividendPool != address(0), "Invalid dividend pool");

        __ERC20_init("DecentraChat Governance", "DGOV");
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        founder = _founder;
        dchatToken = _dchatToken;
        dividendPool = _dividendPool;
        vestingStart = block.timestamp;

        // Initialize phase percentages
        _phasePercentages[0] = 700;
        _phasePercentages[1] = 1400;
        _phasePercentages[2] = 2150;
        _phasePercentages[3] = 2150;
        _phasePercentages[4] = 1800;
        _phasePercentages[5] = 1800;

        _grantRole(DEFAULT_ADMIN_ROLE, _founder);
        _grantRole(AUCTION_MANAGER_ROLE, _founder);

        // Mint total supply to this contract
        _mint(address(this), TOTAL_SUPPLY);

        // Register founder as user
        registeredUsers[_founder] = true;
        totalRegisteredUsers = 1;
    }

    // =========================================================================
    // UUPS UPGRADE AUTHORIZATION
    // =========================================================================

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // =========================================================================
    // USER REGISTRATION
    // =========================================================================

    function registerUser(address user) external onlyRole(AUCTION_MANAGER_ROLE) {
        require(user != address(0), "Invalid address");
        require(!registeredUsers[user], "Already registered");
        registeredUsers[user] = true;
        totalRegisteredUsers++;
        emit UserRegistered(user);
    }

    function registerUserBatch(address[] calldata users) external onlyRole(AUCTION_MANAGER_ROLE) {
        require(users.length <= 200, "Batch too large");
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] != address(0) && !registeredUsers[users[i]]) {
                registeredUsers[users[i]] = true;
                totalRegisteredUsers++;
                emit UserRegistered(users[i]);
            }
        }
    }

    function unregisterUser(address user) external onlyRole(AUCTION_MANAGER_ROLE) {
        require(registeredUsers[user], "Not registered");
        registeredUsers[user] = false;
        totalRegisteredUsers--;
        emit UserUnregistered(user);
    }

    // =========================================================================
    // FOUNDER VESTING (30M: 10M every 12 months)
    // =========================================================================

    function claimFounderVesting() external nonReentrant whenNotPaused {
        require(msg.sender == founder, "Only founder");
        require(founderTranchesClaimed < VESTING_TRANCHES, "All tranches claimed");

        uint256 nextTranche = founderTranchesClaimed + 1;
        uint256 unlockTime = vestingStart + (nextTranche * VESTING_INTERVAL);
        require(block.timestamp >= unlockTime, "Tranche not yet unlocked");

        founderTranchesClaimed = nextTranche;
        _transfer(address(this), founder, FOUNDER_PER_TRANCHE);

        emit VestingClaimed(founder, "founder", nextTranche, FOUNDER_PER_TRANCHE);
    }

    // =========================================================================
    // MARKETING DISTRIBUTION
    // =========================================================================

    function transferMarketingTokens(address recipient, uint256 amount) external nonReentrant whenNotPaused {
        require(msg.sender == founder, "Only founder");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        require(
            totalMarketingDistributed + amount <= MARKETING_ALLOCATION,
            "Exceeds marketing allocation"
        );

        totalMarketingDistributed += amount;
        totalMarketingLocked += amount;

        _transfer(address(this), recipient, amount);

        uint256 lockEnd = block.timestamp + MARKETING_LOCK_PERIOD;
        uint256 vestingEnd = lockEnd + MARKETING_VESTING_PERIOD;
        uint256 lockIndex = marketingLocks[recipient].length;
        marketingLocks[recipient].push(MarketingLock({
            amount: amount,
            lockEnd: lockEnd,
            vestingEnd: vestingEnd,
            claimed: 0
        }));

        marketingLockedCache[recipient] += amount;

        emit MarketingTokensTransferred(recipient, amount, lockEnd, lockIndex);
    }

    function unlockMarketingVesting(uint256 lockIndex) external nonReentrant {
        require(lockIndex < marketingLocks[msg.sender].length, "Invalid lock index");

        MarketingLock storage lock = marketingLocks[msg.sender][lockIndex];
        require(block.timestamp >= lock.lockEnd, "Lock period not expired");

        uint256 vested = _getVestedAmount(lock);
        uint256 claimable = vested - lock.claimed;
        require(claimable > 0, "Nothing to claim");

        lock.claimed += claimable;
        totalMarketingLocked -= claimable;

        if (marketingLockedCache[msg.sender] >= claimable) {
            marketingLockedCache[msg.sender] -= claimable;
        } else {
            marketingLockedCache[msg.sender] = 0;
        }

        emit MarketingTokensUnlocked(msg.sender, lockIndex, claimable);
    }

    function _getVestedAmount(MarketingLock storage lock) internal view returns (uint256) {
        if (block.timestamp < lock.lockEnd) return 0;
        if (block.timestamp >= lock.vestingEnd) return lock.amount;
        uint256 elapsed = block.timestamp - lock.lockEnd;
        return (lock.amount * elapsed) / MARKETING_VESTING_PERIOD;
    }

    /**
     * @notice Override de transfer para impedir transferência de tokens locked de marketing.
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && from != address(this)) {
            uint256 lockedAmount = marketingLockedCache[from];
            if (lockedAmount > 0) {
                lockedAmount = getMarketingLockedBalance(from);
                marketingLockedCache[from] = lockedAmount;
            }
            uint256 balance = balanceOf(from);
            require(balance - lockedAmount >= value, "Cannot transfer locked marketing tokens");
        }
        super._update(from, to, value);
    }

    function getMarketingLockedBalance(address holder) public view returns (uint256) {
        uint256 locked = 0;
        MarketingLock[] storage locks = marketingLocks[holder];
        for (uint256 i = 0; i < locks.length; i++) {
            uint256 vested = _getVestedAmount(locks[i]);
            uint256 stillLocked = locks[i].amount - vested;
            locked += stillLocked;
        }
        return locked;
    }

    function getMarketingClaimable(address holder) public view returns (uint256) {
        uint256 claimable = 0;
        MarketingLock[] storage locks = marketingLocks[holder];
        for (uint256 i = 0; i < locks.length; i++) {
            uint256 vested = _getVestedAmount(locks[i]);
            if (vested > locks[i].claimed) {
                claimable += vested - locks[i].claimed;
            }
        }
        return claimable;
    }

    function getMarketingLocks(address holder) external view returns (
        uint256[] memory amounts,
        uint256[] memory lockEnds,
        uint256[] memory vestingEnds,
        uint256[] memory claimedAmounts,
        uint256[] memory claimableNow
    ) {
        MarketingLock[] storage locks = marketingLocks[holder];
        uint256 len = locks.length;
        amounts = new uint256[](len);
        lockEnds = new uint256[](len);
        vestingEnds = new uint256[](len);
        claimedAmounts = new uint256[](len);
        claimableNow = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            amounts[i] = locks[i].amount;
            lockEnds[i] = locks[i].lockEnd;
            vestingEnds[i] = locks[i].vestingEnd;
            claimedAmounts[i] = locks[i].claimed;
            uint256 vested = _getVestedAmount(locks[i]);
            claimableNow[i] = vested > locks[i].claimed ? vested - locks[i].claimed : 0;
        }
    }

    // =========================================================================
    // VESTING STATUS
    // =========================================================================

    function getFounderVestingStatus() external view returns (
        uint256 totalAllocated,
        uint256 totalClaimed,
        uint256 nextUnlockTime,
        uint256 tranchesClaimed
    ) {
        totalAllocated = FOUNDER_ALLOCATION;
        totalClaimed = founderTranchesClaimed * FOUNDER_PER_TRANCHE;
        if (founderTranchesClaimed < VESTING_TRANCHES) {
            nextUnlockTime = vestingStart + ((founderTranchesClaimed + 1) * VESTING_INTERVAL);
        }
        tranchesClaimed = founderTranchesClaimed;
    }

    function getMarketingDistributionStatus() external view returns (
        uint256 totalAllocated,
        uint256 totalDistributed,
        uint256 totalLocked,
        uint256 totalUnlocked,
        uint256 remaining
    ) {
        totalAllocated = MARKETING_ALLOCATION;
        totalDistributed = totalMarketingDistributed;
        totalLocked = totalMarketingLocked;
        totalUnlocked = totalMarketingDistributed - totalMarketingLocked;
        remaining = MARKETING_ALLOCATION - totalMarketingDistributed;
    }

    // =========================================================================
    // ESCROW POOL
    // =========================================================================

    function depositToEscrow(uint256 amount) external nonReentrant whenNotPaused {
        require(registeredUsers[msg.sender], "Not a registered user");
        require(amount > 0, "Amount must be > 0");
        // [M-06] SafeERC20
        IERC20(dchatToken).safeTransferFrom(msg.sender, address(this), amount);

        escrowBalances[msg.sender].total += amount;
        totalEscrowBalance += amount;

        emit EscrowDeposited(msg.sender, amount, escrowBalances[msg.sender].total);
    }

    function withdrawFromEscrow(uint256 amount) external nonReentrant {
        EscrowBalance storage bal = escrowBalances[msg.sender];
        uint256 available = bal.total - bal.locked;

        require(amount > 0, "Amount must be > 0");
        require(amount <= available, "Insufficient unlocked balance");

        bal.total -= amount;
        totalEscrowBalance -= amount;

        // [M-06] SafeERC20
        IERC20(dchatToken).safeTransfer(msg.sender, amount);

        emit EscrowWithdrawn(msg.sender, amount, bal.total);
    }

    function getEscrowBalance(address user) external view returns (
        uint256 total,
        uint256 locked,
        uint256 available
    ) {
        EscrowBalance storage bal = escrowBalances[user];
        total = bal.total;
        locked = bal.locked;
        available = total - locked;
    }

    // =========================================================================
    // AUCTION SYSTEM
    // =========================================================================

    function initializeAuctions() external onlyRole(AUCTION_MANAGER_ROLE) {
        require(auctionsStartTime == 0, "Already initialized");
        auctionsStartTime = block.timestamp + AUCTION_DELAY;
        currentAuctionId = 0;
    }

    function getTokensForAuction(uint256 auctionNumber) public view returns (uint256) {
        require(auctionNumber >= 1 && auctionNumber <= TOTAL_AUCTIONS, "Invalid auction number");
        uint256 phaseIndex = (auctionNumber - 1) / AUCTIONS_PER_PHASE;
        if (phaseIndex > 5) phaseIndex = 5;
        uint256 phaseTokens = (AUCTION_ALLOCATION * _phasePercentages[phaseIndex]) / BPS_DENOMINATOR;
        return phaseTokens / AUCTIONS_PER_PHASE;
    }

    function startNextAuction() external whenNotPaused {
        require(auctionsStartTime > 0, "Auctions not initialized");
        require(currentAuctionId < TOTAL_AUCTIONS, "All auctions completed");

        if (currentAuctionId > 0) {
            require(auctions[currentAuctionId].finalized, "Previous auction not finalized");
        }

        uint256 nextId = currentAuctionId + 1;
        uint256 scheduledStart = auctionsStartTime + ((nextId - 1) * AUCTION_INTERVAL);
        require(block.timestamp >= scheduledStart, "Too early for next auction");

        uint256 tokensForThisAuction = getTokensForAuction(nextId);

        auctions[nextId] = Auction({
            id: nextId,
            tokensAvailable: tokensForThisAuction,
            startTime: block.timestamp,
            endTime: block.timestamp + AUCTION_DURATION,
            highestPricePerUnit: 0,
            totalBidCount: 0,
            totalBidVolume: 0,
            finalized: false,
            tokensBurned: false,
            totalRevenue: 0,
            tokensSold: 0,
            tokensBurnedAmount: 0,
            antiSnipeCount: 0
        });

        currentAuctionId = nextId;

        emit AuctionStarted(nextId, tokensForThisAuction, block.timestamp, block.timestamp + AUCTION_DURATION);
    }

    function placeBid(uint256 quantity, uint256 pricePerUnit) external nonReentrant whenNotPaused {
        require(registeredUsers[msg.sender], "Not a registered user");

        uint256 auctionId = currentAuctionId;
        Auction storage auction = auctions[auctionId];

        require(auctionId > 0, "No active auction");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.finalized, "Auction finalized");
        require(auctionBids[auctionId].length < MAX_BIDS_PER_AUCTION, "Max bids reached for this auction");
        require(quantity > 0, "Quantity must be > 0");
        require(pricePerUnit > 0, "Price must be > 0");

        require(pricePerUnit >= MIN_BID_PER_DGOV, "Price below minimum (0.01 DCHAT/DGOV)");

        // [F-07] 5% increment enforcement
        if (auction.highestPricePerUnit > 0 && pricePerUnit > auction.highestPricePerUnit) {
            uint256 minIncrement = (auction.highestPricePerUnit * 105) / 100;
            require(pricePerUnit >= minIncrement, "New highest bid must be >= 5% above current highest");
        }

        uint256 totalCost = (quantity * pricePerUnit) / 1e18;
        require(totalCost > 0, "Total cost must be > 0");

        EscrowBalance storage bal = escrowBalances[msg.sender];
        uint256 available = bal.total - bal.locked;
        require(available >= totalCost, "Insufficient unlocked escrow balance");

        bal.locked += totalCost;

        if (pricePerUnit > auction.highestPricePerUnit) {
            auction.highestPricePerUnit = pricePerUnit;
        }

        uint256 bidIndex = auctionBids[auctionId].length;
        auctionBids[auctionId].push(Bid({
            bidder: msg.sender,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            totalCost: totalCost,
            filled: false,
            filledQty: 0,
            refunded: false
        }));

        userBidIndices[auctionId][msg.sender].push(bidIndex);

        auction.totalBidCount++;
        auction.totalBidVolume += quantity;

        // Anti-sniping
        if (auction.endTime - block.timestamp <= ANTI_SNIPE_WINDOW
            && auction.antiSnipeCount < MAX_ANTI_SNIPE_EXTENSIONS) {
            auction.endTime += ANTI_SNIPE_EXTENSION;
            auction.antiSnipeCount++;
            emit AuctionExtended(auctionId, auction.endTime);
        }

        emit BidPlaced(auctionId, msg.sender, quantity, pricePerUnit, totalCost, bidIndex);
    }

    function finalizeAuction(uint256 auctionId) external nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];

        require(auction.id > 0, "Auction does not exist");
        require(block.timestamp >= auction.endTime, "Auction still active");
        require(!auction.finalized, "Already finalized");

        auction.finalized = true;

        Bid[] storage bids = auctionBids[auctionId];

        if (bids.length == 0) {
            _burnUnsoldTokens(auctionId, auction.tokensAvailable);
            emit AuctionFinalized(auctionId, 0, auction.tokensAvailable, 0, 0);
            return;
        }

        uint256[] memory sortedIndices = _sortBidsByPrice(auctionId);
        (uint256 totalSold, uint256 totalRevenueLocal, uint256 remainingTokens) = _fillBids(auctionId, sortedIndices, auction.tokensAvailable);
        _refundUnfilledBids(auctionId, sortedIndices);

        if (remainingTokens > 0) {
            _burnUnsoldTokens(auctionId, remainingTokens);
        }

        if (totalRevenueLocal > 0) {
            // [M-06] SafeERC20
            IERC20(dchatToken).safeTransfer(dividendPool, totalRevenueLocal);
            // [AUTO-03] Notificar DividendPool
            IDividendPool(dividendPool).notifyAuctionDeposit(totalRevenueLocal);
            emit DividendsSent(auctionId, totalRevenueLocal);
        }

        auction.totalRevenue = totalRevenueLocal;
        auction.tokensSold = totalSold;
        totalAuctionRevenue += totalRevenueLocal;

        emit AuctionFinalized(auctionId, totalSold, remainingTokens, totalRevenueLocal, bids.length);
    }

    function _sortBidsByPrice(uint256 auctionId) internal view returns (uint256[] memory) {
        Bid[] storage bids = auctionBids[auctionId];
        uint256[] memory sortedIndices = new uint256[](bids.length);
        for (uint256 i = 0; i < bids.length; i++) {
            sortedIndices[i] = i;
        }
        // Insertion sort — safe with MAX_BIDS_PER_AUCTION = 50 [C-03]
        for (uint256 i = 1; i < sortedIndices.length; i++) {
            uint256 key = sortedIndices[i];
            uint256 j = i;
            while (j > 0 && bids[sortedIndices[j - 1]].pricePerUnit < bids[key].pricePerUnit) {
                sortedIndices[j] = sortedIndices[j - 1];
                j--;
            }
            sortedIndices[j] = key;
        }
        return sortedIndices;
    }

    function _fillBids(
        uint256 auctionId,
        uint256[] memory sortedIndices,
        uint256 tokensAvailable
    ) internal returns (uint256 totalSold, uint256 totalRevenueLocal, uint256 remainingTokens) {
        Bid[] storage bids = auctionBids[auctionId];
        remainingTokens = tokensAvailable;

        for (uint256 i = 0; i < sortedIndices.length && remainingTokens > 0; i++) {
            Bid storage bid = bids[sortedIndices[i]];
            uint256 fillQty = bid.quantity <= remainingTokens ? bid.quantity : remainingTokens;
            uint256 fillCost = (fillQty * bid.pricePerUnit) / 1e18;

            bid.filled = true;
            bid.filledQty = fillQty;
            _transfer(address(this), bid.bidder, fillQty);

            EscrowBalance storage bidderBal = escrowBalances[bid.bidder];
            bidderBal.locked -= bid.totalCost;

            if (bid.totalCost > fillCost) {
                bid.refunded = true;
                emit BidRefunded(auctionId, bid.bidder, sortedIndices[i], bid.totalCost - fillCost);
            }

            // [H-03] Proteção contra underflow
            if (fillCost > bidderBal.total) {
                fillCost = bidderBal.total;
            }
            bidderBal.total -= fillCost;
            totalEscrowBalance -= fillCost;
            remainingTokens -= fillQty;
            totalRevenueLocal += fillCost;
            totalSold += fillQty;

            emit BidFilled(auctionId, bid.bidder, sortedIndices[i], fillQty, fillCost);
        }
    }

    function _refundUnfilledBids(uint256 auctionId, uint256[] memory sortedIndices) internal {
        Bid[] storage bids = auctionBids[auctionId];
        for (uint256 i = 0; i < sortedIndices.length; i++) {
            Bid storage bid = bids[sortedIndices[i]];
            if (!bid.filled) {
                escrowBalances[bid.bidder].locked -= bid.totalCost;
                bid.refunded = true;
                emit BidRefunded(auctionId, bid.bidder, sortedIndices[i], bid.totalCost);
            }
        }
    }

    function _burnUnsoldTokens(uint256 auctionId, uint256 amount) internal {
        _burn(address(this), amount);
        auctions[auctionId].tokensBurned = true;
        auctions[auctionId].tokensBurnedAmount = amount;
        totalTokensBurned += amount;
        emit TokensBurned(auctionId, amount);
    }

    // =========================================================================
    // AUCTION VIEW FUNCTIONS
    // =========================================================================

    function getAuctionInfo(uint256 auctionId) external view returns (
        uint256 tokensAvailable,
        uint256 startTime,
        uint256 endTime,
        uint256 highestPricePerUnit,
        uint256 totalBidCount,
        uint256 totalBidVolume,
        bool finalized
    ) {
        Auction storage a = auctions[auctionId];
        return (
            a.tokensAvailable, a.startTime, a.endTime,
            a.highestPricePerUnit, a.totalBidCount, a.totalBidVolume,
            a.finalized
        );
    }

    function getAuctionResults(uint256 auctionId) external view returns (
        uint256 totalRevenue,
        uint256 tokensSold,
        uint256 tokensBurnedAmount,
        bool isActive
    ) {
        Auction storage a = auctions[auctionId];
        bool active = (a.id > 0 && block.timestamp >= a.startTime && block.timestamp < a.endTime && !a.finalized);
        return (a.totalRevenue, a.tokensSold, a.tokensBurnedAmount, active);
    }

    function getBidInfo(uint256 auctionId, uint256 bidIndex) external view returns (
        address bidder,
        uint256 quantity,
        uint256 pricePerUnit,
        uint256 totalCost,
        bool filled,
        uint256 filledQty,
        bool refunded
    ) {
        Bid storage b = auctionBids[auctionId][bidIndex];
        return (b.bidder, b.quantity, b.pricePerUnit, b.totalCost, b.filled, b.filledQty, b.refunded);
    }

    function getUserBids(uint256 auctionId, address user) external view returns (uint256[] memory) {
        return userBidIndices[auctionId][user];
    }

    function getAuctionBidCount(uint256 auctionId) external view returns (uint256) {
        return auctionBids[auctionId].length;
    }

    function getNextAuctionSchedule() external view returns (
        uint256 nextAuctionId,
        uint256 scheduledStart,
        uint256 tokensAvailable
    ) {
        if (auctionsStartTime == 0 || currentAuctionId >= TOTAL_AUCTIONS) {
            return (0, 0, 0);
        }
        nextAuctionId = currentAuctionId + 1;
        scheduledStart = auctionsStartTime + ((nextAuctionId - 1) * AUCTION_INTERVAL);
        tokensAvailable = getTokensForAuction(nextAuctionId);
    }

    function getAuctionPhase(uint256 auctionNumber) external pure returns (
        uint256 phaseNumber,
        string memory phaseName
    ) {
        require(auctionNumber >= 1 && auctionNumber <= 156, "Invalid auction number");
        uint256 idx = (auctionNumber - 1) / 26;
        if (idx == 0) return (1, "Lancamento");
        if (idx == 1) return (2, "Crescimento");
        if (idx == 2) return (3, "Expansao");
        if (idx == 3) return (4, "Maturidade");
        if (idx == 4) return (5, "Consolidacao");
        return (6, "Final");
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
    // TOKEN QUERY HELPERS
    // =========================================================================

    function getTotalEmitted() public view returns (uint256) {
        return TOTAL_SUPPLY - totalTokensBurned;
    }

    function getVestingWeight(address holder) external view returns (uint256) {
        if (holder == founder) {
            uint256 claimed = founderTranchesClaimed * FOUNDER_PER_TRANCHE;
            return FOUNDER_ALLOCATION - claimed;
        }
        return getMarketingLockedBalance(holder);
    }

    function setGovernanceContract(address _governance) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_governance != address(0), "Invalid address");
        governanceContract = _governance;
        emit GovernanceContractSet(_governance);
    }

    // =========================================================================
    // PROTOCOL STATS
    // =========================================================================

    function getProtocolStats() external view returns (
        uint256 _totalSupply,
        uint256 _circulatingSupply,
        uint256 _totalBurned,
        uint256 _auctionRevenue,
        uint256 _currentAuction,
        uint256 _remainingAuctions
    ) {
        uint256 locked = balanceOf(address(this));
        return (
            TOTAL_SUPPLY,
            totalSupply() - locked,
            totalTokensBurned,
            totalAuctionRevenue,
            currentAuctionId,
            TOTAL_AUCTIONS - currentAuctionId
        );
    }

    function getProtocolStatsExtended() external view returns (
        uint256 _founderClaimed,
        uint256 _marketingDistributed,
        uint256 _registeredUsers,
        uint256 _totalEmitted
    ) {
        return (
            founderTranchesClaimed * FOUNDER_PER_TRANCHE,
            totalMarketingDistributed,
            totalRegisteredUsers,
            getTotalEmitted()
        );
    }

    // =========================================================================
    // ADMIN
    // =========================================================================

    function setDividendPool(address _pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pool != address(0), "Invalid address");
        address oldPool = dividendPool;
        dividendPool = _pool;
        emit DividendPoolUpdated(oldPool, _pool);
    }

    function getFounderDividendWeight() external view returns (uint256) {
        return FOUNDER_ALLOCATION;
    }

    function getTotalDividendWeight() external view returns (uint256) {
        uint256 auctionTokensRemaining = balanceOf(address(this)) - _getVestingTokensRemaining();
        return TOTAL_SUPPLY - totalTokensBurned - auctionTokensRemaining;
    }

    function _getVestingTokensRemaining() internal view returns (uint256) {
        uint256 founderRemaining = FOUNDER_ALLOCATION - (founderTranchesClaimed * FOUNDER_PER_TRANCHE);
        uint256 marketingRemaining = MARKETING_ALLOCATION - totalMarketingDistributed;
        return founderRemaining + marketingRemaining;
    }
}
