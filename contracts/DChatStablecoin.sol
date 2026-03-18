// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
contract DChatStablecoin is ERC20, ERC20Burnable, AccessControl, ReentrancyGuard {

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

    // =========================================================================
    // REDEEM MINIMUM
    // =========================================================================
    uint256 public constant MIN_REDEEM = 5 * 1e18; // 5 $DCHAT ($5 USD) mínimo para resgate

    // =========================================================================
    // FEE DISTRIBUTION (basis points, total = 10000)
    // =========================================================================
    uint16 public constant NODE_FEE_BPS = 7000;       // 70% → Nodes processadores
    uint16 public constant DIVIDEND_FEE_BPS = 2000;    // 20% → Pool de dividendos $DGOV
    uint16 public constant RESERVE_FEE_BPS = 1000;     // 10% → Reserva operacional

    // =========================================================================
    // COST PER BYTE (in wei of $DCHAT, 18 decimals)
    // =========================================================================
    uint256 public costPerByte = 1e9;  // 0.000000001 $DCHAT per byte (base)
    uint256 public constant MAX_COST_PER_BYTE = 1e15;  // Safety cap

    // =========================================================================
    // DATA TYPE MULTIPLIERS (basis points, 10000 = 1.0x)
    // =========================================================================
    uint16 public textMultiplier = 10000;    // 1.0x
    uint16 public imageMultiplier = 15000;   // 1.5x
    uint16 public videoMultiplier = 20000;   // 2.0x
    uint16 public audioMultiplier = 15000;   // 1.5x
    uint16 public fileMultiplier = 12000;    // 1.2x

    // =========================================================================
    // ADDRESSES
    // =========================================================================
    address public dividendPool;     // Smart contract de dividendos $DGOV
    address public reserveWallet;    // Wallet da reserva operacional
    address public founder;          // Wallet do fundador

    // =========================================================================
    // NODE REGISTRY
    // =========================================================================
    struct Node {
        address wallet;
        uint256 stake;
        uint256 totalEarned;
        uint256 pendingRewards;
        bool active;
        uint256 registeredAt;
    }

    mapping(address => Node) public nodes;
    address[] public activeNodeList;
    uint256 public totalNodeStake;

    // =========================================================================
    // ACTIVATION FEE
    // =========================================================================
    uint256 public activationFee = 1e17;  // 0.1 $DCHAT ($0.10)

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

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================
    constructor(
        address _founder,
        address _dividendPool,
        address _reserveWallet,
        address _usdc,
        address _usdt
    ) ERC20("DecentraChat Stablecoin", "DCHAT") {
        require(_founder != address(0), "Invalid founder");
        require(_dividendPool != address(0), "Invalid dividend pool");
        require(_reserveWallet != address(0), "Invalid reserve wallet");

        founder = _founder;
        dividendPool = _dividendPool;
        reserveWallet = _reserveWallet;

        _grantRole(DEFAULT_ADMIN_ROLE, _founder);
        _grantRole(MINTER_ROLE, _founder);

        // Register accepted collateral tokens
        if (_usdc != address(0)) {
            acceptedCollateral[_usdc] = true;
            collateralTokens.push(_usdc);
            emit CollateralTokenAdded(_usdc);
        }
        if (_usdt != address(0)) {
            acceptedCollateral[_usdt] = true;
            collateralTokens.push(_usdt);
            emit CollateralTokenAdded(_usdt);
        }
    }

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
    ) external nonReentrant {
        require(acceptedCollateral[collateralToken], "Token not accepted as collateral");
        require(collateralAmount > 0, "Amount must be > 0");

        // USDC/USDT have 6 decimals, $DCHAT has 18 decimals
        // 1 USDC (1e6) = 1 $DCHAT (1e18)
        uint256 dchatAmount = collateralAmount * 1e12; // Scale 6 → 18 decimals

        // Transfer collateral from user to Vault (this contract)
        bool success = IERC20(collateralToken).transferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );
        require(success, "Collateral transfer failed");

        // Update vault tracking
        vaultBalance[collateralToken] += collateralAmount;
        totalVaultBalance += collateralAmount;

        // Mint $DCHAT 1:1 to user
        _mint(msg.sender, dchatAmount);

        emit Minted(msg.sender, collateralToken, collateralAmount, dchatAmount, block.timestamp);
    }

    /**
     * @notice Admin mint for initial liquidity or bridge operations.
     * @dev Only MINTER_ROLE can call. Used for bootstrapping and bridge.
     * @param to Recipient of minted tokens
     * @param amount Amount of $DCHAT to mint (18 decimals)
     */
    function adminMint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        _mint(to, amount);
        emit Minted(to, address(0), 0, amount, block.timestamp);
    }

    // =========================================================================
    // VAULT — REDEEM (Return $DCHAT → Receive Collateral 1:1)
    // =========================================================================

    /**
     * @notice Redeem $DCHAT for USDC or USDT at 1:1 ratio.
     * @dev Burns $DCHAT and releases collateral from Vault.
     *      Minimum redeem: 20 $DCHAT.
     *      User chooses which collateral token to receive.
     * @param collateralToken Address of USDC or USDT to receive
     * @param dchatAmount Amount of $DCHAT to redeem (18 decimals)
     */
    function redeem(
        address collateralToken,
        uint256 dchatAmount
    ) external nonReentrant {
        require(acceptedCollateral[collateralToken], "Token not accepted");
        require(dchatAmount >= MIN_REDEEM, "Minimum redeem is 5 DCHAT");
        require(balanceOf(msg.sender) >= dchatAmount, "Insufficient DCHAT balance");

        // Convert $DCHAT (18 decimals) back to collateral (6 decimals)
        uint256 collateralAmount = dchatAmount / 1e12;
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

        // Release collateral to user
        bool success = IERC20(collateralToken).transfer(msg.sender, collateralAmount);
        require(success, "Collateral transfer failed");

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
    function processMessage(
        address sender,
        address recipient,
        uint256 byteSize,
        uint8 dataType
    ) external onlyRole(RELAYER_ROLE) nonReentrant {
        require(sender != address(0), "Invalid sender");
        require(byteSize > 0, "Empty message");
        require(dataType <= 4, "Invalid data type");

        uint256 totalFee = calculateFee(byteSize, dataType);
        require(balanceOf(sender) >= totalFee, "Insufficient DCHAT balance");

        // Calculate distribution
        uint256 nodeFee = (totalFee * NODE_FEE_BPS) / 10000;
        uint256 dividendFee = (totalFee * DIVIDEND_FEE_BPS) / 10000;
        uint256 reserveFee = totalFee - nodeFee - dividendFee;

        // Transfer fees (CIRCULATION, not burn)
        _transfer(sender, address(this), totalFee);

        // Distribute to nodes (proportional to stake)
        if (activeNodeList.length > 0 && totalNodeStake > 0) {
            _distributeToNodes(nodeFee);
        } else {
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

        nodes[nodeAddress] = Node({
            wallet: nodeAddress,
            stake: stake,
            totalEarned: 0,
            pendingRewards: 0,
            active: true,
            registeredAt: block.timestamp
        });

        activeNodeList.push(nodeAddress);
        totalNodeStake += stake;

        emit NodeRegistered(nodeAddress, stake);
    }

    function removeNode(address nodeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(nodes[nodeAddress].active, "Node not active");

        nodes[nodeAddress].active = false;
        totalNodeStake -= nodes[nodeAddress].stake;

        for (uint256 i = 0; i < activeNodeList.length; i++) {
            if (activeNodeList[i] == nodeAddress) {
                activeNodeList[i] = activeNodeList[activeNodeList.length - 1];
                activeNodeList.pop();
                break;
            }
        }

        uint256 pending = nodes[nodeAddress].pendingRewards;
        if (pending > 0) {
            nodes[nodeAddress].pendingRewards = 0;
            _transfer(address(this), nodeAddress, pending);
        }

        emit NodeRemoved(nodeAddress, pending);
    }

    function claimNodeRewards() external nonReentrant {
        uint256 pending = nodes[msg.sender].pendingRewards;
        require(pending > 0, "No pending rewards");

        nodes[msg.sender].pendingRewards = 0;
        nodes[msg.sender].totalEarned += pending;
        _transfer(address(this), msg.sender, pending);

        emit NodeRewardDistributed(msg.sender, pending);
    }

    // =========================================================================
    // ACTIVATION FEE
    // =========================================================================

    function payActivationFee(address user) external onlyRole(RELAYER_ROLE) {
        require(balanceOf(user) >= activationFee, "Insufficient balance for activation");
        _transfer(user, reserveWallet, activationFee);
        emit ActivationFeePaid(user, activationFee);
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    function addCollateralToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Invalid token");
        require(!acceptedCollateral[token], "Already accepted");
        acceptedCollateral[token] = true;
        collateralTokens.push(token);
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
        activationFee = _newFee;
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
        return (n.stake, n.totalEarned, n.pendingRewards, n.active, n.registeredAt);
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
     * @notice Check the collateralization ratio (should always be >= 100%).
     * @return ratio The ratio in basis points (10000 = 100%)
     */
    function getCollateralizationRatio() external view returns (uint256) {
        if (totalSupply() == 0) return 10000;
        // totalVaultBalance is in 6 decimals (USDC/USDT)
        // totalSupply is in 18 decimals
        // Normalize: vault * 1e12 to get 18 decimals, then ratio
        uint256 vaultIn18 = totalVaultBalance * 1e12;
        return (vaultIn18 * 10000) / totalSupply();
    }

    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================

    function _distributeToNodes(uint256 amount) internal {
        uint256 distributed = 0;
        for (uint256 i = 0; i < activeNodeList.length; i++) {
            address nodeAddr = activeNodeList[i];
            if (nodes[nodeAddr].active && nodes[nodeAddr].stake > 0) {
                uint256 share = (amount * nodes[nodeAddr].stake) / totalNodeStake;
                nodes[nodeAddr].pendingRewards += share;
                distributed += share;
            }
        }
        if (distributed < amount && activeNodeList.length > 0) {
            nodes[activeNodeList[0]].pendingRewards += (amount - distributed);
        }
    }

    function _getMultiplier(uint8 dataType) internal view returns (uint16) {
        if (dataType == 0) return textMultiplier;
        if (dataType == 1) return imageMultiplier;
        if (dataType == 2) return videoMultiplier;
        if (dataType == 3) return audioMultiplier;
        return fileMultiplier;
    }
}
