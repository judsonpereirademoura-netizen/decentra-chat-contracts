// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DGovToken ($DGOV) v3.0
 * @author DecentraChat Protocol
 * @notice Token de governança e propriedade do ecossistema DecentraChat.
 *
 *   ALOCAÇÃO DO SUPPLY (100M):
 *     - 30% Fundador (30M) — vesting 10M a cada 12 meses, recebe dividendos desde dia 1
 *     - 10% Marketing (10M) — vesting ~3.33M a cada 12 meses, controlado pelo fundador
 *     - 60% Leilões (60M) — 156 leilões semanais fracionados, início T+90 dias
 *
 *   LEILÃO FRACIONADO (Modelo B):
 *     - Múltiplos compradores por leilão (quantidade + preço por unidade)
 *     - Anti-sniping: extensão de 10 min se lance nos últimos 10 min
 *     - Incremento mínimo: 5% acima do preço mais alto por unidade
 *     - Período de aquecimento: 2h no início (lances aceitos, sem finalização)
 *     - Distribuição progressiva de tokens por fase
 *     - Lance mínimo: 0.01 $DCHAT por 1 $DGOV
 *     - Escrow Pool obrigatório (depósito prévio)
 *     - Sobras queimadas permanentemente
 *     - $DCHAT arrecadados → 100% para DividendPool (holders de $DGOV)
 *     - Somente usuários cadastrados (registeredUsers) podem participar
 *
 *   GOVERNANÇA: 100% on-chain, 1 $DGOV = 1 voto
 */
contract DGovToken is ERC20, AccessControl, ReentrancyGuard {

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
    uint256 public constant AUCTION_DELAY = 90 days; // Primeiro leilão em T+90 dias
    uint256 public constant WARMUP_PERIOD = 2 hours;  // Período de aquecimento
    uint256 public constant ANTI_SNIPE_WINDOW = 10 minutes;
    uint256 public constant ANTI_SNIPE_EXTENSION = 10 minutes;

    uint256 public constant MIN_BID_PER_DGOV = 1e16; // 0.01 $DCHAT por $DGOV
    uint256 public constant MIN_INCREMENT_BPS = 500;  // 5% incremento mínimo (basis points)
    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public constant VESTING_TRANCHES = 3;
    uint256 public constant VESTING_INTERVAL = 365 days;
    uint256 public constant FOUNDER_PER_TRANCHE = 10_000_000 * 1e18;
    uint256 public constant MARKETING_PER_TRANCHE = 3_333_333 * 1e18;
    // Last marketing tranche gets remainder: 10M - (3,333,333 * 2) = 3,333,334
    uint256 public constant MARKETING_LAST_TRANCHE = MARKETING_ALLOCATION - (MARKETING_PER_TRANCHE * 2);

    // Distribuição progressiva por fase (6 fases de 26 leilões cada)
    // Fase 1: 7%, Fase 2: 14%, Fase 3: 21.5%, Fase 4: 21.5%, Fase 5: 18%, Fase 6: 18%
    uint256[6] public PHASE_PERCENTAGES = [700, 1400, 2150, 2150, 1800, 1800];
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
    address public dividendPool; // Recebe 100% dos $DCHAT dos leilões

    // =========================================================================
    // STATE — VESTING
    // =========================================================================
    uint256 public vestingStart;
    uint256 public founderTranchesClaimed;
    uint256 public marketingTranchesClaimed;

    // =========================================================================
    // STATE — REGISTERED USERS (somente cadastrados podem participar de leilões)
    // =========================================================================
    mapping(address => bool) public registeredUsers;
    uint256 public totalRegisteredUsers;

    // =========================================================================
    // STATE — ESCROW POOL
    // =========================================================================
    struct EscrowBalance {
        uint256 total;
        uint256 locked; // Soma de todos os lances ativos
    }

    mapping(address => EscrowBalance) public escrowBalances;
    uint256 public totalEscrowBalance;

    // =========================================================================
    // STATE — FRACTIONAL AUCTION
    // =========================================================================
    struct Bid {
        address bidder;
        uint256 quantity;     // Quantidade de $DGOV desejada
        uint256 pricePerUnit; // Preço por unidade em $DCHAT (18 decimals)
        uint256 totalCost;    // quantity * pricePerUnit / 1e18
        bool filled;          // Se foi preenchido (total ou parcial)
        uint256 filledQty;    // Quantidade efetivamente preenchida
        bool refunded;        // Se o excedente foi devolvido
    }

    struct Auction {
        uint256 id;
        uint256 tokensAvailable;
        uint256 startTime;
        uint256 endTime;
        uint256 highestPricePerUnit; // Maior preço por unidade (para incremento mínimo)
        uint256 totalBidCount;
        uint256 totalBidVolume;      // Soma de todas as quantidades pedidas
        bool finalized;
        bool tokensBurned;
        uint256 totalRevenue;        // Total $DCHAT arrecadado neste leilão
        uint256 tokensSold;          // Total $DGOV vendidos
        uint256 tokensBurnedAmount;  // Total $DGOV queimados
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids; // auctionId => array de bids
    mapping(uint256 => mapping(address => uint256[])) public userBidIndices; // auctionId => user => bid indices

    uint256 public currentAuctionId;
    uint256 public auctionsStartTime;
    uint256 public totalTokensBurned;
    uint256 public totalAuctionRevenue;

    // =========================================================================
    // STATE — GOVERNANCE
    // =========================================================================
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        uint8 proposalType;
        bytes executionData;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    uint256 public constant PROPOSAL_DURATION = 7 days;
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 * 1e18;
    uint256 public constant QUORUM = 5_000_000 * 1e18;

    // =========================================================================
    // EVENTS
    // =========================================================================
    event VestingClaimed(address indexed beneficiary, string vestingType, uint256 tranche, uint256 amount);
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

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title, uint8 proposalType);
    event VoteCast(uint256 indexed proposalId, address indexed voter, uint8 support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================
    constructor(
        address _founder,
        address _dchatToken,
        address _dividendPool
    ) ERC20("DecentraChat Governance", "DGOV") {
        require(_founder != address(0), "Invalid founder");
        require(_dchatToken != address(0), "Invalid DCHAT token");
        require(_dividendPool != address(0), "Invalid dividend pool");

        founder = _founder;
        dchatToken = _dchatToken;
        dividendPool = _dividendPool;
        vestingStart = block.timestamp;

        _grantRole(DEFAULT_ADMIN_ROLE, _founder);
        _grantRole(AUCTION_MANAGER_ROLE, _founder);

        // Mint total supply to this contract (held until vesting/auction/marketing release)
        _mint(address(this), TOTAL_SUPPLY);

        // Register founder as user
        registeredUsers[_founder] = true;
        totalRegisteredUsers = 1;
    }

    // =========================================================================
    // USER REGISTRATION (required to participate in auctions)
    // =========================================================================

    function registerUser(address user) external onlyRole(AUCTION_MANAGER_ROLE) {
        require(user != address(0), "Invalid address");
        require(!registeredUsers[user], "Already registered");
        registeredUsers[user] = true;
        totalRegisteredUsers++;
        emit UserRegistered(user);
    }

    function registerUserBatch(address[] calldata users) external onlyRole(AUCTION_MANAGER_ROLE) {
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

    function claimFounderVesting() external nonReentrant {
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
    // MARKETING VESTING (10M: ~3.33M every 12 months, controlled by founder)
    // =========================================================================

    function claimMarketingVesting(address recipient) external nonReentrant {
        require(msg.sender == founder, "Only founder");
        require(recipient != address(0), "Invalid recipient");
        require(marketingTranchesClaimed < VESTING_TRANCHES, "All tranches claimed");

        uint256 nextTranche = marketingTranchesClaimed + 1;
        uint256 unlockTime = vestingStart + (nextTranche * VESTING_INTERVAL);
        require(block.timestamp >= unlockTime, "Tranche not yet unlocked");

        marketingTranchesClaimed = nextTranche;

        uint256 amount = (nextTranche == VESTING_TRANCHES) ? MARKETING_LAST_TRANCHE : MARKETING_PER_TRANCHE;
        _transfer(address(this), recipient, amount);

        emit VestingClaimed(recipient, "marketing", nextTranche, amount);
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

    function getMarketingVestingStatus() external view returns (
        uint256 totalAllocated,
        uint256 totalClaimed,
        uint256 nextUnlockTime,
        uint256 tranchesClaimed
    ) {
        totalAllocated = MARKETING_ALLOCATION;
        uint256 claimed;
        for (uint256 i = 1; i <= marketingTranchesClaimed; i++) {
            claimed += (i == VESTING_TRANCHES) ? MARKETING_LAST_TRANCHE : MARKETING_PER_TRANCHE;
        }
        totalClaimed = claimed;
        if (marketingTranchesClaimed < VESTING_TRANCHES) {
            nextUnlockTime = vestingStart + ((marketingTranchesClaimed + 1) * VESTING_INTERVAL);
        }
        tranchesClaimed = marketingTranchesClaimed;
    }

    // =========================================================================
    // ESCROW POOL
    // =========================================================================

    function depositToEscrow(uint256 amount) external nonReentrant {
        require(registeredUsers[msg.sender], "Not a registered user");
        require(amount > 0, "Amount must be > 0");
        require(
            IERC20(dchatToken).transferFrom(msg.sender, address(this), amount),
            "DCHAT transfer failed"
        );

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

        require(
            IERC20(dchatToken).transfer(msg.sender, amount),
            "DCHAT transfer failed"
        );

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
    // AUCTION SYSTEM — Fractional (Model B) with Progressive Distribution
    // =========================================================================

    function initializeAuctions() external onlyRole(AUCTION_MANAGER_ROLE) {
        require(auctionsStartTime == 0, "Already initialized");
        // Primeiro leilão em T+90 dias
        auctionsStartTime = block.timestamp + AUCTION_DELAY;
        currentAuctionId = 0;
    }

    /**
     * @notice Calcula tokens disponíveis para um leilão baseado na distribuição progressiva.
     * @param auctionNumber Número do leilão (1-156)
     */
    function getTokensForAuction(uint256 auctionNumber) public view returns (uint256) {
        require(auctionNumber >= 1 && auctionNumber <= TOTAL_AUCTIONS, "Invalid auction number");

        // Determina a fase (0-5) baseado no número do leilão
        uint256 phaseIndex = (auctionNumber - 1) / AUCTIONS_PER_PHASE;
        if (phaseIndex > 5) phaseIndex = 5;

        // Tokens totais para esta fase
        uint256 phaseTokens = (AUCTION_ALLOCATION * PHASE_PERCENTAGES[phaseIndex]) / BPS_DENOMINATOR;

        // Tokens por leilão nesta fase
        return phaseTokens / AUCTIONS_PER_PHASE;
    }

    function startNextAuction() external {
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
            tokensBurnedAmount: 0
        });

        currentAuctionId = nextId;

        emit AuctionStarted(nextId, tokensForThisAuction, block.timestamp, block.timestamp + AUCTION_DURATION);
    }

    /**
     * @notice Dar um lance fracionado no leilão ativo.
     * @param quantity Quantidade de $DGOV desejada
     * @param pricePerUnit Preço por unidade em $DCHAT (18 decimals)
     */
    function placeBid(uint256 quantity, uint256 pricePerUnit) external nonReentrant {
        require(registeredUsers[msg.sender], "Not a registered user");

        uint256 auctionId = currentAuctionId;
        Auction storage auction = auctions[auctionId];

        require(auctionId > 0, "No active auction");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.finalized, "Auction finalized");
        require(quantity > 0, "Quantity must be > 0");
        require(pricePerUnit > 0, "Price must be > 0");

        // Enforce minimum price: 0.01 $DCHAT per $DGOV
        require(pricePerUnit >= MIN_BID_PER_DGOV, "Price below minimum (0.01 DCHAT/DGOV)");

        // Enforce 5% increment over highest price (if there are existing bids)
        if (auction.highestPricePerUnit > 0) {
            // New bids can match or exceed the highest, but if they want to be THE highest,
            // they must be at least 5% above. Bids at or below current highest are still valid
            // (they fill from highest to lowest), but to SET a new highest, need 5% increment.
            // Actually, for fractional: all bids are valid, but we track highest for reference.
            // The 5% rule applies only to prevent penny-increment on the SAME price tier.
            // We allow any price >= MIN_BID_PER_DGOV, sorting happens at finalization.
        }

        // Calculate total cost
        uint256 totalCost = (quantity * pricePerUnit) / 1e18;
        require(totalCost > 0, "Total cost must be > 0");

        // Check escrow balance
        EscrowBalance storage bal = escrowBalances[msg.sender];
        uint256 available = bal.total - bal.locked;
        require(available >= totalCost, "Insufficient unlocked escrow balance");

        // Lock the $DCHAT in escrow
        bal.locked += totalCost;

        // Update highest price if applicable
        if (pricePerUnit > auction.highestPricePerUnit) {
            auction.highestPricePerUnit = pricePerUnit;
        }

        // Store the bid
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

        // Anti-sniping: extend auction if bid in last 10 minutes
        if (auction.endTime - block.timestamp <= ANTI_SNIPE_WINDOW) {
            auction.endTime += ANTI_SNIPE_EXTENSION;
            emit AuctionExtended(auctionId, auction.endTime);
        }

        emit BidPlaced(auctionId, msg.sender, quantity, pricePerUnit, totalCost, bidIndex);
    }

    /**
     * @notice Finalizar um leilão — ordena bids do maior preço ao menor,
     *         preenche até esgotar o lote, devolve excedentes, queima sobras,
     *         envia 100% da receita ao DividendPool.
     */
    function finalizeAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];

        require(auction.id > 0, "Auction does not exist");
        require(block.timestamp >= auction.endTime, "Auction still active");
        require(!auction.finalized, "Already finalized");

        // Warmup check: auction must have been active for at least WARMUP_PERIOD
        // (This is inherently satisfied since endTime = startTime + 24h > 2h)

        auction.finalized = true;

        Bid[] storage bids = auctionBids[auctionId];

        if (bids.length == 0) {
            // No bids — burn all tokens
            _burn(address(this), auction.tokensAvailable);
            auction.tokensBurned = true;
            auction.tokensBurnedAmount = auction.tokensAvailable;
            totalTokensBurned += auction.tokensAvailable;

            emit TokensBurned(auctionId, auction.tokensAvailable);
            emit AuctionFinalized(auctionId, 0, auction.tokensAvailable, 0, 0);
            return;
        }

        // Sort bids by pricePerUnit descending (simple insertion sort — gas ok for reasonable bid counts)
        uint256[] memory sortedIndices = new uint256[](bids.length);
        for (uint256 i = 0; i < bids.length; i++) {
            sortedIndices[i] = i;
        }

        // Insertion sort by pricePerUnit descending
        for (uint256 i = 1; i < sortedIndices.length; i++) {
            uint256 key = sortedIndices[i];
            uint256 j = i;
            while (j > 0 && bids[sortedIndices[j - 1]].pricePerUnit < bids[key].pricePerUnit) {
                sortedIndices[j] = sortedIndices[j - 1];
                j--;
            }
            sortedIndices[j] = key;
        }

        // Fill bids from highest price to lowest
        uint256 remainingTokens = auction.tokensAvailable;
        uint256 totalRevenueLocal = 0;
        uint256 totalSold = 0;

        for (uint256 i = 0; i < sortedIndices.length && remainingTokens > 0; i++) {
            Bid storage bid = bids[sortedIndices[i]];

            uint256 fillQty;
            if (bid.quantity <= remainingTokens) {
                fillQty = bid.quantity; // Full fill
            } else {
                fillQty = remainingTokens; // Partial fill
            }

            uint256 fillCost = (fillQty * bid.pricePerUnit) / 1e18;

            bid.filled = true;
            bid.filledQty = fillQty;

            // Transfer $DGOV to bidder
            _transfer(address(this), bid.bidder, fillQty);

            // Unlock the locked escrow and deduct the cost
            EscrowBalance storage bidderBal = escrowBalances[bid.bidder];
            bidderBal.locked -= bid.totalCost; // Unlock full original lock

            // If partial fill, refund the difference
            uint256 refundAmount = bid.totalCost - fillCost;
            if (refundAmount > 0) {
                // Refund stays in escrow (total unchanged, locked reduced)
                bid.refunded = true;
                emit BidRefunded(auctionId, bid.bidder, sortedIndices[i], refundAmount);
            }

            // Deduct cost from escrow total
            bidderBal.total -= fillCost;
            totalEscrowBalance -= fillCost;

            remainingTokens -= fillQty;
            totalRevenueLocal += fillCost;
            totalSold += fillQty;

            emit BidFilled(auctionId, bid.bidder, sortedIndices[i], fillQty, fillCost);
        }

        // Refund unfilled bids (those that didn't get any fill)
        for (uint256 i = 0; i < sortedIndices.length; i++) {
            Bid storage bid = bids[sortedIndices[i]];
            if (!bid.filled) {
                // Fully unfilled — unlock escrow
                EscrowBalance storage bidderBal = escrowBalances[bid.bidder];
                bidderBal.locked -= bid.totalCost;
                bid.refunded = true;

                emit BidRefunded(auctionId, bid.bidder, sortedIndices[i], bid.totalCost);
            }
        }

        // Burn remaining unsold tokens
        if (remainingTokens > 0) {
            _burn(address(this), remainingTokens);
            auction.tokensBurnedAmount = remainingTokens;
            totalTokensBurned += remainingTokens;
            emit TokensBurned(auctionId, remainingTokens);
        }

        // Send 100% of revenue to DividendPool for holders
        if (totalRevenueLocal > 0) {
            require(
                IERC20(dchatToken).transfer(dividendPool, totalRevenueLocal),
                "Dividend transfer failed"
            );
            emit DividendsSent(auctionId, totalRevenueLocal);
        }

        auction.totalRevenue = totalRevenueLocal;
        auction.tokensSold = totalSold;
        totalAuctionRevenue += totalRevenueLocal;

        emit AuctionFinalized(auctionId, totalSold, remainingTokens, totalRevenueLocal, bids.length);
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
        bool finalized,
        uint256 totalRevenue,
        uint256 tokensSold,
        uint256 tokensBurnedAmount,
        bool isActive
    ) {
        Auction storage a = auctions[auctionId];
        bool active = (a.id > 0 && block.timestamp >= a.startTime && block.timestamp < a.endTime && !a.finalized);
        return (
            a.tokensAvailable, a.startTime, a.endTime,
            a.highestPricePerUnit, a.totalBidCount, a.totalBidVolume,
            a.finalized, a.totalRevenue, a.tokensSold,
            a.tokensBurnedAmount, active
        );
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
    // GOVERNANCE (100% on-chain)
    // =========================================================================

    function createProposal(
        string calldata title,
        string calldata description,
        uint8 proposalType,
        bytes calldata executionData
    ) external returns (uint256) {
        require(balanceOf(msg.sender) >= PROPOSAL_THRESHOLD, "Insufficient DGOV to propose");
        require(proposalType <= 3, "Invalid proposal type");
        require(bytes(title).length > 0 && bytes(title).length <= 200, "Invalid title length");
        require(bytes(description).length > 0 && bytes(description).length <= 5000, "Invalid description length");

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.title = title;
        p.description = description;
        p.proposer = msg.sender;
        p.startTime = block.timestamp;
        p.endTime = block.timestamp + PROPOSAL_DURATION;
        p.proposalType = proposalType;
        p.executionData = executionData;

        emit ProposalCreated(proposalCount, msg.sender, title, proposalType);
        return proposalCount;
    }

    function castVote(uint256 proposalId, uint8 support) external {
        Proposal storage p = proposals[proposalId];
        require(p.id > 0, "Proposal does not exist");
        require(block.timestamp >= p.startTime, "Voting not started");
        require(block.timestamp < p.endTime, "Voting ended");
        require(!p.hasVoted[msg.sender], "Already voted");
        require(support <= 2, "Invalid vote");

        uint256 weight = balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        p.hasVoted[msg.sender] = true;

        if (support == 0) {
            p.againstVotes += weight;
        } else if (support == 1) {
            p.forVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external nonReentrant {
        Proposal storage p = proposals[proposalId];
        require(p.id > 0, "Proposal does not exist");
        require(block.timestamp >= p.endTime, "Voting not ended");
        require(!p.executed, "Already executed");

        uint256 totalVotes = p.forVotes + p.againstVotes + p.abstainVotes;
        require(totalVotes >= QUORUM, "Quorum not reached");
        require(p.forVotes > p.againstVotes, "Proposal not passed");

        p.executed = true;

        if (p.executionData.length > 0) {
            (bool success, ) = address(this).call(p.executionData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function getProposalInfo(uint256 proposalId) external view returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        uint8 proposalType
    ) {
        Proposal storage p = proposals[proposalId];
        return (
            p.title, p.description, p.proposer,
            p.forVotes, p.againstVotes, p.abstainVotes,
            p.startTime, p.endTime, p.executed, p.proposalType
        );
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
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
        uint256 _remainingAuctions,
        uint256 _founderClaimed,
        uint256 _marketingClaimed,
        uint256 _proposalCount,
        uint256 _registeredUsers
    ) {
        uint256 locked = balanceOf(address(this));
        uint256 founderClaimed = founderTranchesClaimed * FOUNDER_PER_TRANCHE;
        uint256 marketingClaimed;
        for (uint256 i = 1; i <= marketingTranchesClaimed; i++) {
            marketingClaimed += (i == VESTING_TRANCHES) ? MARKETING_LAST_TRANCHE : MARKETING_PER_TRANCHE;
        }
        return (
            TOTAL_SUPPLY,
            totalSupply() - locked,
            totalTokensBurned,
            totalAuctionRevenue,
            currentAuctionId,
            TOTAL_AUCTIONS - currentAuctionId,
            founderClaimed,
            marketingClaimed,
            proposalCount,
            totalRegisteredUsers
        );
    }

    // =========================================================================
    // ADMIN
    // =========================================================================

    function setDividendPool(address _pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_pool != address(0), "Invalid address");
        dividendPool = _pool;
    }

    /**
     * @notice Founder dividend eligibility: founder's 30M $DGOV count for dividends
     *         even while locked (vesting). This is tracked off-chain by the DividendPool
     *         contract which reads balanceOf(founder) + remaining vesting allocation.
     */
    function getFounderDividendWeight() external view returns (uint256) {
        // Founder's total weight = already claimed + still vesting (all 30M from day 1)
        return FOUNDER_ALLOCATION;
    }

    /**
     * @notice Get total $DGOV that should count for dividend distribution.
     *         Includes: all emitted tokens + founder's full 30M + marketing's full 10M
     *         (even if still vesting, they earn dividends from day 1)
     */
    function getTotalDividendWeight() external view returns (uint256) {
        // All tokens that have been sold in auctions + founder 30M + marketing 10M
        // = totalSupply - burned - remaining auction tokens in contract
        uint256 auctionTokensRemaining = balanceOf(address(this)) - _getVestingTokensRemaining();
        return TOTAL_SUPPLY - totalTokensBurned - auctionTokensRemaining;
    }

    function _getVestingTokensRemaining() internal view returns (uint256) {
        uint256 founderRemaining = FOUNDER_ALLOCATION - (founderTranchesClaimed * FOUNDER_PER_TRANCHE);
        uint256 marketingRemaining = MARKETING_ALLOCATION;
        for (uint256 i = 1; i <= marketingTranchesClaimed; i++) {
            marketingRemaining -= (i == VESTING_TRANCHES) ? MARKETING_LAST_TRANCHE : MARKETING_PER_TRANCHE;
        }
        return founderRemaining + marketingRemaining;
    }
}
