// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol"; // [F-14]
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title DChatStablecoin ($DCHAT)
 * @author DecentraChat Protocol
 * @notice Stablecoin de utilidade do ecossistema DecentraChat.
 *         Peg: 1 $DCHAT = 1 USD (1:1 com dólar americano).
 *         Lastro: USDC e USDT depositados no Vault on-chain.
 *         Supply: Ilimitado (Mint-on-Demand, auto-regulado pela demanda).
 *         O token CIRCULA entre participantes — só é queimado no redeem.
 *
 * @dev Arquitetura:
 *   - Vault: Aceita USDC/USDT como colateral, minta $DCHAT 1:1
 *   - Redeem: Devolve $DCHAT, queima e libera colateral (mínimo 20 $DCHAT)
 *   - Messaging: RELAYER_ROLE processa pagamentos e distribui taxas em tempo real
 *   - Gas: Account Abstraction (ERC-4337) — gas pago em $DCHAT, invisível ao usuário
 *   - Settlement: Individual em tempo real (transparência máxima)
 */
contract DChatStablecoin is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // =========================================================================
    // ROLES
    // =========================================================================
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    // =========================================================================
    // SUPPLY MODEL: Infinite (Mint-on-Demand)
    // =========================================================================
    // Supply é ILIMITADO — $DCHAT é mintado 1:1 quando colateral é depositado
    // e queimado 1:1 quando colateral é resgatado (redeem).
    // O supply se auto-regula pela demanda, sempre 100% lastreado.
    // Modelo idêntico ao USDC: sem cap, mint/burn sob demanda.

    // =========================================================================
    // VAULT — COLATERAL ACEITO (USDC e USDT)
    // =========================================================================
    mapping(address => bool) public acceptedCollateral;
    address[] public collateralTokens;

    // Vault balances per collateral token
    mapping(address => uint256) public vaultBalance;
    uint256 public totalVaultBalance; // Total USD value in vault

    // [C-02] Dynamic decimal tracking per collateral token
    mapping(address => uint8) public collateralDecimals;

    // =========================================================================
    // REDEEM MINIMUM
    // =========================================================================
    uint256 public constant MIN_REDEEM = 5 * 1e18; // 5 $DCHAT ($5 USD) mínimo para resgate
    uint256 public constant MAX_ADMIN_MINT = 100_000 * 1e18; // [F-09] Cap de $100k para mint sem colateral
    uint256 public totalAdminMinted; // [F-09] Tracking de mint sem colateral

    // =========================================================================
    // FEE DISTRIBUTION (basis points, total = 10000)
    // =========================================================================
    uint16 public constant NODE_FEE_BPS = 7000;       // 70% → Nodes processadores
    uint16 public constant DIVIDEND_FEE_BPS = 2000;    // 20% → Pool de dividendos $DGOV
    uint16 public constant RESERVE_FEE_BPS = 1000;     // 10% → Reserva operacional

    // =========================================================================
    // COST PER BYTE (in wei of $DCHAT, 18 decimals)
    // =========================================================================
    uint256 public costPerByte;  // 0.000000001 $DCHAT per byte (base)
    uint256 public constant MAX_COST_PER_BYTE = 1e15;  // Safety cap

    // =========================================================================
    // DATA TYPE MULTIPLIERS (basis points, 10000 = 1.0x)
    // =========================================================================
    uint16 public textMultiplier;    // 1.0x
    uint16 public imageMultiplier;   // 1.5x
    uint16 public videoMultiplier;   // 2.0x
    uint16 public audioMultiplier;   // 1.5x
    uint16 public fileMultiplier;    // 1.2x

    // =========================================================================
    // ADDRESSES
    // =========================================================================
    address public dividendPool;     // Smart contract de dividendos $DGOV
    address public reserveWallet;    // Carteira pessoal do fundador para despesas operacionais (hosting, Twilio, infra)
    address public founder;          // Wallet do fundador

    // =========================================================================
    // [F-10] RELAYER ALLOWANCE — Usuário pré-aprova limite diário
    // =========================================================================
    mapping(address => uint256) public relayerDailyLimit;    // Limite diário aprovado pelo user
    mapping(address => uint256) public relayerDailySpent;    // Gasto hoje pelo relayer
    mapping(address => uint256) public relayerLastResetDay;  // Dia do último reset

    event RelayerAllowanceSet(address indexed user, uint256 dailyLimit);
    event RelayerAllowanceSpent(address indexed user, uint256 amount, uint256 remaining);

    // =========================================================================
    // [F-11] NODE REGISTRY — Points-per-token (sem loop na distribuição)
    // =========================================================================
    uint256 private constant NODE_PRECISION = 1e36;
    uint256 public nodeRewardPerToken;     // Acumulador global
    uint256 public nodeTotalDistributed;   // Total distribuído all-time

    struct Node {
        address wallet;
        uint256 stake;
        uint256 totalEarned;
        uint256 rewardDebt;       // [F-11] Snapshot do rewardPerToken no momento do registro
        bool active;
        uint256 registeredAt;
    }

    mapping(address => Node) public nodes;
    address[] public activeNodeList;
    uint256 public totalNodeStake;

    // =========================================================================
    // ACTIVATION FEE
    // =========================================================================
    uint256 public activationFee;  // 0.1 $DCHAT ($0.10)

    // =========================================================================
    // STATISTICS
    // =========================================================================
    uint256 public totalMessagesProcessed;
    uint256 public totalBytesProcessed;
    uint256 public totalFeesCollected;

    // =========================================================================
    // EVENTS
    // =========================================================================
    event Minted(
        address indexed depositor,
        address indexed collateralToken,
        uint256 collateralAmount,
        uint256 dchatMinted,
        uint256 timestamp
    );

    event Redeemed(
        address indexed redeemer,
        address indexed collateralToken,
        uint256 dchatBurned,
        uint256 collateralReturned,
        uint256 timestamp
    );

    event MessageProcessed(
        address indexed sender,
        address indexed recipient,
        uint256 byteSize,
        uint8 dataType,
        uint256 totalFee,
        uint256 nodeFee,
        uint256 dividendFee,
        uint256 reserveFee,
        uint256 timestamp
    );

    event CollateralTokenAdded(address indexed token);
    event CollateralTokenRemoved(address indexed token);
    event NodeRegistered(address indexed node, uint256 stake);
    event NodeRemoved(address indexed node, uint256 pendingRewards);
    event NodeRewardDistributed(address indexed node, uint256 amount);
    event CostPerByteUpdated(uint256 oldCost, uint256 newCost);
    event ActivationFeePaid(address indexed user, uint256 amount);
    event MultiplierUpdated(uint8 dataType, uint16 oldMultiplier, uint16 newMultiplier);
    event ActivationFeeUpdated(uint256 oldFee, uint256 newFee); // [L-04]

    // =========================================================================
    // CONSTRUCTOR & INITIALIZER (UUPS Upgradeable)
    // =========================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _founder,
        address _dividendPool,
        address _reserveWallet,
        address _usdc,
        uint8 _usdcDecimals,
        address _usdt,
        uint8 _usdtDecimals
    ) initializer public {
        __ERC20_init("DecentraChat Stablecoin", "DCHAT");
        __ERC20Burnable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        require(_founder != address(0), "Invalid founder");
        require(_dividendPool != address(0), "Invalid dividend pool");
        require(_reserveWallet != address(0), "Invalid reserve wallet");

        founder = _founder;
        dividendPool = _dividendPool;
        reserveWallet = _reserveWallet;

        // Initialize state variables
        costPerByte = 1e9;
        textMultiplier = 10000;    // 1.0x
        imageMultiplier = 15000;   // 1.5x
        videoMultiplier = 20000;   // 2.0x
        audioMultiplier = 15000;   // 1.5x
        fileMultiplier = 12000;    // 1.2x
        activationFee = 1e17;      // 0.1 $DCHAT ($0.10)

        _grantRole(DEFAULT_ADMIN_ROLE, _founder);
        _grantRole(MINTER_ROLE, _founder);

        // Register accepted collateral tokens
        if (_usdc != address(0)) {
            acceptedCollateral[_usdc] = true;
            collateralTokens.push(_usdc);
            collateralDecimals[_usdc] = _usdcDecimals;
            emit CollateralTokenAdded(_usdc);
        }
        if (_usdt != address(0)) {
            acceptedCollateral[_usdt] = true;
            collateralTokens.push(_usdt);
            collateralDecimals[_usdt] = _usdtDecimals;
            emit CollateralTokenAdded(_usdt);
        }
    }

    // =========================================================================
    // UUPS UPGRADE AUTHORIZATION
    // =========================================================================

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // =========================================================================
    // VAULT — MINT (Deposit Collateral → Receive $DCHAT 1:1)
    // =========================================================================

    /**
     * @notice Deposit USDC or USDT to mint $DCHAT at 1:1 ratio.
     * @dev User must approve this contract to spend their collateral first.
     *      1 USDC (6 decimals) = 1 $DCHAT (18 decimals).
     *      Collateral stays locked in this contract (Vault).
     * @param collateralToken Address of USDC or USDT contract
     * @param collateralAmount Amount of collateral to deposit (6 decimals for USDC/USDT)
     */
    function mint(
        address collateralToken,
        uint256 collateralAmount
    ) external nonReentrant whenNotPaused {
        require(acceptedCollateral[collateralToken], "Token not accepted as collateral");
        require(collateralAmount > 0, "Amount must be > 0");

        // [M-02] Fee-on-transfer protection: balance-before/after pattern
        uint256 balBefore = IERC20(collateralToken).balanceOf(address(this));
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        uint256 received = IERC20(collateralToken).balanceOf(address(this)) - balBefore;

        // [C-02] Dynamic decimal conversion
        uint256 dchatAmount = received * 10**(18 - collateralDecimals[collateralToken]);

        // Update vault tracking (use received amount)
        vaultBalance[collateralToken] += received;
        totalVaultBalance += received;

        // Mint $DCHAT 1:1 to user
        _mint(msg.sender, dchatAmount);

        emit Minted(msg.sender, collateralToken, received, dchatAmount, block.timestamp);
    }

    /**
     * @notice Admin mint for initial liquidity or bridge operations.
     * @dev Only MINTER_ROLE can call. Used for bootstrapping and bridge.
     * @param to Recipient of minted tokens
     * @param amount Amount of $DCHAT to mint (18 decimals)
     */
    function adminMint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        require(totalAdminMinted + amount <= MAX_ADMIN_MINT, "Admin mint cap exceeded"); // [F-09]
        totalAdminMinted += amount; // [F-09]
        _mint(to, amount);
        emit Minted(to, address(0), 0, amount, block.timestamp);
    }

    // =========================================================================
    // VAULT — REDEEM (Return $DCHAT → Receive Collateral 1:1)
    // =========================================================================

    /**
     * @notice Redeem $DCHAT for USDC or USDT at 1:1 ratio.
     * @dev Burns $DCHAT and releases collateral from Vault.
     *      Minimum redeem: 5 $DCHAT.
     *      User chooses which collateral token to receive.
     * @param collateralToken Address of USDC or USDT to receive
     * @param dchatAmount Amount of $DCHAT to redeem (18 decimals)
     */
    function redeem(
        address collateralToken,
        uint256 dchatAmount
    ) external nonReentrant whenNotPaused {
        require(acceptedCollateral[collateralToken], "Token not accepted");
        require(dchatAmount >= MIN_REDEEM, "Minimum redeem is 5 DCHAT");
        require(balanceOf(msg.sender) >= dchatAmount, "Insufficient DCHAT balance");

        // [C-02] Dynamic decimal conversion
        uint256 collateralAmount = dchatAmount / 10**(18 - collateralDecimals[collateralToken]);
        require(collateralAmount > 0, "Amount too small after conversion");

        // Check vault has enough collateral
        require(
            vaultBalance[collateralToken] >= collateralAmount,
            "Insufficient vault balance for this collateral"
        );

        // Burn $DCHAT
        _burn(msg.sender, dchatAmount);

        // Update vault tracking
        vaultBalance[collateralToken] -= collateralAmount;
        totalVaultBalance -= collateralAmount;

        // [M-06] Release collateral to user using SafeERC20
        IERC20(collateralToken).safeTransfer(msg.sender, collateralAmount);

        emit Redeemed(msg.sender, collateralToken, dchatAmount, collateralAmount, block.timestamp);
    }

    // =========================================================================
    // MESSAGE PROCESSING (Real-time settlement)
    // =========================================================================

    /**
     * @notice Process a message payment in real-time.
     * @dev Calculates fee based on byte size and data type, then distributes
     *      70% to nodes, 20% to dividend pool, 10% to reserve.
     *      Settlement is INDIVIDUAL and REAL-TIME for maximum transparency.
     */
    /**
     * @notice [F-10] Usuário aprova limite diário que o relayer pode gastar.
     * @dev Chamada pelo próprio usuário (não pelo relayer).
     *      O relayer só pode processar mensagens até este limite por dia.
     * @param dailyLimit Limite diário em $DCHAT (18 decimals). 0 = revogar.
     */
    function approveRelayerAllowance(uint256 dailyLimit) external {
        relayerDailyLimit[msg.sender] = dailyLimit;
        emit RelayerAllowanceSet(msg.sender, dailyLimit);
    }

    /**
     * @notice Get remaining relayer allowance for a user today.
     */
    function getRelayerRemainingAllowance(address user) external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        uint256 spent = relayerLastResetDay[user] == today ? relayerDailySpent[user] : 0;
        uint256 limit = relayerDailyLimit[user];
        return spent < limit ? limit - spent : 0;
    }

    function processMessage(
        address sender,
        address recipient,
        uint256 byteSize,
        uint8 dataType
    ) external onlyRole(RELAYER_ROLE) nonReentrant whenNotPaused {
        require(sender != address(0), "Invalid sender");
        require(recipient != address(0), "Invalid recipient");
        require(sender != recipient, "Cannot message yourself"); // [H-02]
        require(byteSize > 0, "Empty message");
        require(dataType <= 4, "Invalid data type");

        uint256 totalFee = calculateFee(byteSize, dataType);
        require(balanceOf(sender) >= totalFee, "Insufficient DCHAT balance");

        // [F-10] Check relayer allowance
        uint256 today = block.timestamp / 1 days;
        if (relayerLastResetDay[sender] != today) {
            relayerDailySpent[sender] = 0;
            relayerLastResetDay[sender] = today;
        }
        require(relayerDailyLimit[sender] > 0, "User has not approved relayer");
        require(
            relayerDailySpent[sender] + totalFee <= relayerDailyLimit[sender],
            "Relayer daily limit exceeded"
        );
        relayerDailySpent[sender] += totalFee;

        // Calculate distribution
        uint256 nodeFee = (totalFee * NODE_FEE_BPS) / 10000;
        uint256 dividendFee = (totalFee * DIVIDEND_FEE_BPS) / 10000;
        uint256 reserveFee = totalFee - nodeFee - dividendFee;

        // Transfer fees (CIRCULATION, not burn)
        _transfer(sender, address(this), totalFee);

        // [F-11] Distribute to nodes via points-per-token (O(1), no loop)
        if (totalNodeStake > 0) {
            nodeRewardPerToken += (nodeFee * NODE_PRECISION) / totalNodeStake;
            nodeTotalDistributed += nodeFee;
        } else {
            // No nodes active — send to reserve
            _transfer(address(this), reserveWallet, nodeFee);
        }

        // Transfer to dividend pool (→ $DGOV holders)
        _transfer(address(this), dividendPool, dividendFee);

        // Transfer to reserve (→ gas/operational costs)
        _transfer(address(this), reserveWallet, reserveFee);

        // Update statistics
        totalMessagesProcessed++;
        totalBytesProcessed += byteSize;
        totalFeesCollected += totalFee;

        emit MessageProcessed(
            sender, recipient, byteSize, dataType,
            totalFee, nodeFee, dividendFee, reserveFee,
            block.timestamp
        );

        emit RelayerAllowanceSpent(
            sender, totalFee,
            relayerDailyLimit[sender] - relayerDailySpent[sender]
        );
    }

    /**
     * @notice Calculate the fee for a message based on size and type.
     */
    function calculateFee(uint256 byteSize, uint8 dataType) public view returns (uint256) {
        uint16 multiplier = _getMultiplier(dataType);
        return (byteSize * costPerByte * multiplier) / 10000;
    }

    // =========================================================================
    // NODE MANAGEMENT
    // =========================================================================

    function registerNode(address nodeAddress, uint256 stake) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(nodeAddress != address(0), "Invalid node address");
        require(!nodes[nodeAddress].active, "Node already active");
        require(activeNodeList.length < 500, "Max nodes reached");
        require(stake > 0, "Stake must be > 0");

        nodes[nodeAddress] = Node({
            wallet: nodeAddress,
            stake: stake,
            totalEarned: 0,
            rewardDebt: nodeRewardPerToken,  // [F-11] Snapshot
            active: true,
            registeredAt: block.timestamp
        });

        activeNodeList.push(nodeAddress);
        totalNodeStake += stake;

        emit NodeRegistered(nodeAddress, stake);
    }

    function removeNode(address nodeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(nodes[nodeAddress].active, "Node not active");

        // [F-11] Claim pending before removal
        uint256 pending = _getNodePendingRewards(nodeAddress);
        if (pending > 0) {
            nodes[nodeAddress].totalEarned += pending;
            _transfer(address(this), nodeAddress, pending);
            emit NodeRewardDistributed(nodeAddress, pending);
        }

        nodes[nodeAddress].active = false;
        totalNodeStake -= nodes[nodeAddress].stake;

        for (uint256 i = 0; i < activeNodeList.length; i++) {
            if (activeNodeList[i] == nodeAddress) {
                activeNodeList[i] = activeNodeList[activeNodeList.length - 1];
                activeNodeList.pop();
                break;
            }
        }

        emit NodeRemoved(nodeAddress, pending);
    }

    /**
     * @notice [F-11] Claim accumulated node rewards (points-per-token).
     */
    function claimNodeRewards() external nonReentrant {
        require(nodes[msg.sender].active, "Not an active node");
        uint256 pending = _getNodePendingRewards(msg.sender);
        require(pending > 0, "No pending rewards");

        nodes[msg.sender].rewardDebt = nodeRewardPerToken;
        nodes[msg.sender].totalEarned += pending;
        _transfer(address(this), msg.sender, pending);

        emit NodeRewardDistributed(msg.sender, pending);
    }

    /**
     * @notice [F-11] Get pending rewards for a node (view).
     */
    function getNodePendingRewards(address nodeAddress) external view returns (uint256) {
        return _getNodePendingRewards(nodeAddress);
    }

    // =========================================================================
    // ACTIVATION FEE
    // =========================================================================

    function payActivationFee(address user) external onlyRole(RELAYER_ROLE) whenNotPaused {
        require(balanceOf(user) >= activationFee, "Insufficient balance for activation");
        // [SA-08] Verificar que o user aprovou o relayer e tem limite suficiente
        require(relayerDailyLimit[user] > 0, "User has not approved relayer");
        uint256 today = block.timestamp / 1 days;
        if (relayerLastResetDay[user] != today) {
            relayerDailySpent[user] = 0;
            relayerLastResetDay[user] = today;
        }
        require(
            relayerDailySpent[user] + activationFee <= relayerDailyLimit[user],
            "Relayer daily limit exceeded for activation"
        );
        relayerDailySpent[user] += activationFee;
        _transfer(user, reserveWallet, activationFee);
        emit ActivationFeePaid(user, activationFee);
    }

    // =========================================================================
    // [F-14] CIRCUIT BREAKER — PAUSE/UNPAUSE
    // =========================================================================

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    function addCollateralToken(address token, uint8 decimals) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Invalid token");
        require(!acceptedCollateral[token], "Already accepted");
        acceptedCollateral[token] = true;
        collateralTokens.push(token);
        collateralDecimals[token] = decimals;
        emit CollateralTokenAdded(token);
    }

    function removeCollateralToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(acceptedCollateral[token], "Not accepted");
        require(vaultBalance[token] == 0, "Vault still holds this token");
        acceptedCollateral[token] = false;

        for (uint256 i = 0; i < collateralTokens.length; i++) {
            if (collateralTokens[i] == token) {
                collateralTokens[i] = collateralTokens[collateralTokens.length - 1];
                collateralTokens.pop();
                break;
            }
        }
        emit CollateralTokenRemoved(token);
    }

    function setCostPerByte(uint256 _newCost) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newCost > 0 && _newCost <= MAX_COST_PER_BYTE, "Invalid cost");
        uint256 oldCost = costPerByte;
        costPerByte = _newCost;
        emit CostPerByteUpdated(oldCost, _newCost);
    }

    function setMultiplier(uint8 dataType, uint16 newMultiplier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(dataType <= 4, "Invalid data type");
        require(newMultiplier >= 5000 && newMultiplier <= 50000, "Multiplier out of range");
        uint16 oldMultiplier = _getMultiplier(dataType);
        if (dataType == 0) textMultiplier = newMultiplier;
        else if (dataType == 1) imageMultiplier = newMultiplier;
        else if (dataType == 2) videoMultiplier = newMultiplier;
        else if (dataType == 3) audioMultiplier = newMultiplier;
        else fileMultiplier = newMultiplier;
        emit MultiplierUpdated(dataType, oldMultiplier, newMultiplier);
    }

    function setActivationFee(uint256 _newFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newFee <= 1e18, "Fee too high");
        uint256 oldFee = activationFee;
        activationFee = _newFee;
        emit ActivationFeeUpdated(oldFee, _newFee); // [L-04]
    }

    function setDividendPool(address _newPool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newPool != address(0), "Invalid address");
        dividendPool = _newPool;
    }

    function setReserveWallet(address _newReserve) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newReserve != address(0), "Invalid address");
        reserveWallet = _newReserve;
    }

    // =========================================================================
    // VIEW FUNCTIONS
    // =========================================================================

    function getActiveNodeCount() external view returns (uint256) {
        return activeNodeList.length;
    }

    function getNodeInfo(address nodeAddress) external view returns (
        uint256 stake,
        uint256 totalEarned,
        uint256 pendingRewards,
        bool active,
        uint256 registeredAt
    ) {
        Node storage n = nodes[nodeAddress];
        uint256 pending = _getNodePendingRewards(nodeAddress);
        return (n.stake, n.totalEarned, pending, n.active, n.registeredAt);
    }

    function getProtocolStats() external view returns (
        uint256 _totalMessages,
        uint256 _totalBytes,
        uint256 _totalFees,
        uint256 _totalVaultBalance,
        uint256 _activeNodes,
        uint256 _totalSupply
    ) {
        return (
            totalMessagesProcessed,
            totalBytesProcessed,
            totalFeesCollected,
            totalVaultBalance,
            activeNodeList.length,
            totalSupply()
        );
    }

    function getVaultInfo() external view returns (
        uint256 _totalBalance,
        uint256 _collateralTokenCount
    ) {
        return (totalVaultBalance, collateralTokens.length);
    }

    function getCollateralBalance(address token) external view returns (uint256) {
        return vaultBalance[token];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return collateralTokens;
    }

    /**
     * @notice [F-13] Check the collateralization ratio.
     * @dev Desconta totalAdminMinted do supply para refletir ratio real.
     *      Tokens mintados via adminMint não têm colateral correspondente.
     * @return ratio The ratio in basis points (10000 = 100%)
     */
    function getCollateralizationRatio() external view returns (uint256) {
        uint256 collateralizedSupply = totalSupply() > totalAdminMinted
            ? totalSupply() - totalAdminMinted
            : 0;
        if (collateralizedSupply == 0) return 10000;
        uint256 vaultIn18 = totalVaultBalance * 1e12;
        return (vaultIn18 * 10000) / collateralizedSupply;
    }

    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================

    /**
     * @notice [F-11] Calculate pending rewards for a node using points-per-token.
     */
    function _getNodePendingRewards(address nodeAddress) internal view returns (uint256) {
        Node storage n = nodes[nodeAddress];
        if (!n.active || n.stake == 0) return 0;
        return (n.stake * (nodeRewardPerToken - n.rewardDebt)) / NODE_PRECISION;
    }

    function _getMultiplier(uint8 dataType) internal view returns (uint16) {
        if (dataType == 0) return textMultiplier;
        if (dataType == 1) return imageMultiplier;
        if (dataType == 2) return videoMultiplier;
        if (dataType == 3) return audioMultiplier;
        return fileMultiplier;
    }
}
