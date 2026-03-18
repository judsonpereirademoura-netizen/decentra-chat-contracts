// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DChatToken
 * @author DecentraChat — Judson Moura
 * @notice Token ERC-20 do ecossistema DecentraChat com tokenomics on-chain.
 * @dev Implementa billing por byte, distribuição automática para nodes/fundador/staking,
 *      mecanismo de burn deflacionário e governança de taxas.
 *
 * Tokenomics:
 *   - Supply Total: 1.000.000.000 DCHAT (1 bilhão)
 *   - Custo base por byte: configurável pelo owner
 *   - Distribuição de taxas: 70% nodes, 20% fundador, 10% staking pool
 *   - Burn: 1% de cada transação de mensagem é queimado (deflação)
 *
 * Distribuição Inicial:
 *   - 40% Venda pública / Liquidez
 *   - 25% Treasury / Desenvolvimento
 *   - 20% Fundador (com vesting)
 *   - 10% Staking Pool inicial
 *   - 5%  Airdrops / Marketing
 */
contract DChatToken is ERC20, ERC20Burnable, ERC20Permit, Ownable, ReentrancyGuard, Pausable {

    // ═══════════════════════════════════════════════════════════════
    // CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 bilhão
    uint256 public constant BASIS_POINTS = 10_000; // 100% = 10000 bps

    // Distribuição de taxas (em basis points)
    uint256 public constant NODE_SHARE = 7_000;     // 70%
    uint256 public constant FOUNDER_SHARE = 2_000;   // 20%
    uint256 public constant STAKING_SHARE = 1_000;   // 10%

    // Burn rate por mensagem (em basis points)
    uint256 public constant BURN_RATE = 100; // 1%

    // Distribuição inicial (em basis points)
    uint256 public constant PUBLIC_SALE_SHARE = 4_000;   // 40%
    uint256 public constant TREASURY_SHARE = 2_500;       // 25%
    uint256 public constant FOUNDER_INITIAL_SHARE = 2_000; // 20%
    uint256 public constant STAKING_INITIAL_SHARE = 1_000; // 10%
    uint256 public constant AIRDROP_SHARE = 500;           // 5%

    // ═══════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Custo base por byte em wei de DCHAT (ajustável)
    uint256 public costPerByte;

    /// @notice Multiplicadores por tipo de dado (em basis points, 10000 = 1x)
    mapping(uint8 => uint256) public dataTypeMultiplier;

    /// @notice Endereço do fundador (recebe 20% das taxas)
    address public founderAddress;

    /// @notice Endereço do contrato de staking
    address public stakingPool;

    /// @notice Endereço do treasury
    address public treasuryAddress;

    /// @notice Total de bytes processados na rede
    uint256 public totalBytesProcessed;

    /// @notice Total de mensagens processadas
    uint256 public totalMessagesProcessed;

    /// @notice Total de DCHAT queimados
    uint256 public totalBurned;

    /// @notice Total de DCHAT distribuídos para nodes
    uint256 public totalNodeRewards;

    /// @notice Total de DCHAT distribuídos para o fundador
    uint256 public totalFounderRewards;

    /// @notice Total de DCHAT enviados ao staking pool
    uint256 public totalStakingRewards;

    /// @notice Registro de nodes autorizados
    mapping(address => bool) public authorizedNodes;

    /// @notice Contagem de nodes autorizados
    uint256 public nodeCount;

    /// @notice Registro de recompensas pendentes por node
    mapping(address => uint256) public pendingNodeRewards;

    /// @notice Vesting do fundador — tokens liberados
    uint256 public founderVestingStart;
    uint256 public founderVestingDuration;
    uint256 public founderTokensClaimed;
    uint256 public founderTotalVesting;

    /// @notice Pausa de emergência ativa
    bool public emergencyMode;

    // ═══════════════════════════════════════════════════════════════
    // DATA TYPE CONSTANTS
    // ═══════════════════════════════════════════════════════════════

    uint8 public constant TYPE_TEXT = 0;
    uint8 public constant TYPE_IMAGE = 1;
    uint8 public constant TYPE_AUDIO = 2;
    uint8 public constant TYPE_VIDEO = 3;
    uint8 public constant TYPE_DOCUMENT = 4;
    uint8 public constant TYPE_LOCATION = 5;

    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════

    event MessageProcessed(
        address indexed sender,
        address indexed recipient,
        uint256 byteSize,
        uint8 dataType,
        uint256 totalCost,
        uint256 nodeFee,
        uint256 founderFee,
        uint256 stakingFee,
        uint256 burnedAmount,
        uint256 timestamp
    );

    event NodeRegistered(address indexed node, uint256 timestamp);
    event NodeRemoved(address indexed node, uint256 timestamp);
    event NodeRewardClaimed(address indexed node, uint256 amount, uint256 timestamp);
    event RemovedNodeRewardClaimed(address indexed node, uint256 amount, uint256 timestamp);
    event CostPerByteUpdated(uint256 oldCost, uint256 newCost);
    event DataTypeMultiplierUpdated(uint8 dataType, uint256 oldMultiplier, uint256 newMultiplier);
    event StakingPoolUpdated(address oldPool, address newPool);
    event FounderVestingClaimed(address indexed founder, uint256 amount, uint256 timestamp);
    event EmergencyModeToggled(bool active, uint256 timestamp);

    // ═══════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════

    modifier onlyAuthorizedNode() {
        require(authorizedNodes[msg.sender], "DChatToken: not an authorized node");
        _;
    }

    modifier notEmergency() {
        require(!emergencyMode, "DChatToken: emergency mode active");
        _;
    }

    // ═══════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Inicializa o token $DCHAT com distribuição inicial
     * @param _founderAddress Endereço do fundador
     * @param _treasuryAddress Endereço do treasury
     * @param _stakingPool Endereço do contrato de staking
     * @param _publicSaleAddress Endereço para tokens de venda pública
     * @param _airdropAddress Endereço para tokens de airdrop
     * @param _costPerByte Custo base por byte em wei de DCHAT
     */
    constructor(
        address _founderAddress,
        address _treasuryAddress,
        address _stakingPool,
        address _publicSaleAddress,
        address _airdropAddress,
        uint256 _costPerByte
    ) ERC20("DecentraChat", "DCHAT") ERC20Permit("DecentraChat") Ownable(msg.sender) {
        require(_founderAddress != address(0), "DChatToken: founder is zero address");
        require(_treasuryAddress != address(0), "DChatToken: treasury is zero address");
        require(_stakingPool != address(0), "DChatToken: staking pool is zero address");
        require(_publicSaleAddress != address(0), "DChatToken: public sale is zero address");
        require(_airdropAddress != address(0), "DChatToken: airdrop is zero address");
        require(_costPerByte > 0, "DChatToken: cost per byte must be > 0");

        founderAddress = _founderAddress;
        treasuryAddress = _treasuryAddress;
        stakingPool = _stakingPool;
        costPerByte = _costPerByte;

        // Distribuição inicial
        uint256 publicSaleAmount = (TOTAL_SUPPLY * PUBLIC_SALE_SHARE) / BASIS_POINTS;
        uint256 treasuryAmount = (TOTAL_SUPPLY * TREASURY_SHARE) / BASIS_POINTS;
        uint256 founderAmount = (TOTAL_SUPPLY * FOUNDER_INITIAL_SHARE) / BASIS_POINTS;
        uint256 stakingAmount = (TOTAL_SUPPLY * STAKING_INITIAL_SHARE) / BASIS_POINTS;
        uint256 airdropAmount = (TOTAL_SUPPLY * AIRDROP_SHARE) / BASIS_POINTS;

        // Mint para cada endereço
        _mint(_publicSaleAddress, publicSaleAmount);
        _mint(_treasuryAddress, treasuryAmount);
        _mint(address(this), founderAmount); // Fundador com vesting — tokens ficam no contrato
        _mint(_stakingPool, stakingAmount);
        _mint(_airdropAddress, airdropAmount);

        // Configurar vesting do fundador (2 anos)
        founderVestingStart = block.timestamp;
        founderVestingDuration = 730 days; // 2 anos
        founderTotalVesting = founderAmount;
        founderTokensClaimed = 0;

        // Configurar multiplicadores padrão por tipo de dado
        dataTypeMultiplier[TYPE_TEXT] = 10_000;      // 1.0x (base)
        dataTypeMultiplier[TYPE_IMAGE] = 12_000;     // 1.2x
        dataTypeMultiplier[TYPE_AUDIO] = 15_000;     // 1.5x
        dataTypeMultiplier[TYPE_VIDEO] = 20_000;     // 2.0x
        dataTypeMultiplier[TYPE_DOCUMENT] = 11_000;  // 1.1x
        dataTypeMultiplier[TYPE_LOCATION] = 8_000;   // 0.8x
    }

    // ═══════════════════════════════════════════════════════════════
    // CORE BILLING FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Calcula o custo de uma mensagem baseado no tamanho em bytes e tipo de dado
     * @param _byteSize Tamanho da mensagem em bytes
     * @param _dataType Tipo de dado (0=text, 1=image, 2=audio, 3=video, 4=document, 5=location)
     * @return totalCost Custo total em DCHAT (wei)
     * @return nodeFee Taxa para nodes
     * @return founderFee Taxa para fundador
     * @return stakingFee Taxa para staking pool
     * @return burnAmount Quantidade a ser queimada
     */
    function calculateMessageCost(uint256 _byteSize, uint8 _dataType)
        public
        view
        returns (
            uint256 totalCost,
            uint256 nodeFee,
            uint256 founderFee,
            uint256 stakingFee,
            uint256 burnAmount
        )
    {
        require(_byteSize > 0, "DChatToken: byte size must be > 0");

        uint256 multiplier = dataTypeMultiplier[_dataType];
        if (multiplier == 0) multiplier = 10_000; // Default 1.0x

        // Custo base = bytes * costPerByte * multiplier
        uint256 baseCost = (_byteSize * costPerByte * multiplier) / BASIS_POINTS;

        // Calcular burn (1% do custo base)
        burnAmount = (baseCost * BURN_RATE) / BASIS_POINTS;

        // Custo total = base + burn
        totalCost = baseCost + burnAmount;

        // Distribuição do custo base (sem o burn)
        nodeFee = (baseCost * NODE_SHARE) / BASIS_POINTS;
        founderFee = (baseCost * FOUNDER_SHARE) / BASIS_POINTS;
        stakingFee = baseCost - nodeFee - founderFee; // Resto vai para staking (evita rounding errors)
    }

    /**
     * @notice Processa o pagamento de uma mensagem na rede DecentraChat
     * @param _recipient Endereço do destinatário da mensagem
     * @param _byteSize Tamanho da mensagem em bytes
     * @param _dataType Tipo de dado enviado
     * @param _relayNode Endereço do node que processou a mensagem
     */
    function processMessage(
        address _recipient,
        uint256 _byteSize,
        uint8 _dataType,
        address _relayNode
    ) external nonReentrant whenNotPaused notEmergency {
        require(_recipient != address(0), "DChatToken: recipient is zero address");
        require(_recipient != msg.sender, "DChatToken: cannot message yourself");
        require(_byteSize > 0, "DChatToken: byte size must be > 0");
        require(authorizedNodes[_relayNode], "DChatToken: relay node not authorized");

        (
            uint256 totalCost,
            uint256 nodeFee,
            uint256 founderFee,
            uint256 stakingFee,
            uint256 burnAmount
        ) = calculateMessageCost(_byteSize, _dataType);

        require(balanceOf(msg.sender) >= totalCost, "DChatToken: insufficient balance");

        // 1. Transferir taxa do node para recompensas pendentes
        _transfer(msg.sender, address(this), nodeFee);
        pendingNodeRewards[_relayNode] += nodeFee;
        totalNodeRewards += nodeFee;

        // 2. Transferir taxa do fundador
        _transfer(msg.sender, founderAddress, founderFee);
        totalFounderRewards += founderFee;

        // 3. Transferir para staking pool
        _transfer(msg.sender, stakingPool, stakingFee);
        totalStakingRewards += stakingFee;

        // 4. Burn deflacionário
        _burn(msg.sender, burnAmount);
        totalBurned += burnAmount;

        // 5. Atualizar métricas
        totalBytesProcessed += _byteSize;
        totalMessagesProcessed += 1;

        emit MessageProcessed(
            msg.sender,
            _recipient,
            _byteSize,
            _dataType,
            totalCost,
            nodeFee,
            founderFee,
            stakingFee,
            burnAmount,
            block.timestamp
        );
    }

    /**
     * @notice Processa múltiplas mensagens em batch (otimização de gas)
     * @param _recipients Array de destinatários
     * @param _byteSizes Array de tamanhos em bytes
     * @param _dataTypes Array de tipos de dados
     * @param _relayNodes Array de nodes relay
     */
    function processMessageBatch(
        address[] calldata _recipients,
        uint256[] calldata _byteSizes,
        uint8[] calldata _dataTypes,
        address[] calldata _relayNodes
    ) external nonReentrant whenNotPaused notEmergency {
        require(_recipients.length == _byteSizes.length, "DChatToken: array length mismatch");
        require(_recipients.length == _dataTypes.length, "DChatToken: array length mismatch");
        require(_recipients.length == _relayNodes.length, "DChatToken: array length mismatch");
        require(_recipients.length <= 50, "DChatToken: batch too large");

        for (uint256 i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "DChatToken: recipient is zero address");
            require(_recipients[i] != msg.sender, "DChatToken: cannot message yourself");
            require(_byteSizes[i] > 0, "DChatToken: byte size must be > 0");
            require(authorizedNodes[_relayNodes[i]], "DChatToken: relay node not authorized");

            (
                uint256 totalCost,
                uint256 nodeFee,
                uint256 founderFee,
                uint256 stakingFee,
                uint256 burnAmount
            ) = calculateMessageCost(_byteSizes[i], _dataTypes[i]);

            require(balanceOf(msg.sender) >= totalCost, "DChatToken: insufficient balance");

            _transfer(msg.sender, address(this), nodeFee);
            pendingNodeRewards[_relayNodes[i]] += nodeFee;
            totalNodeRewards += nodeFee;

            _transfer(msg.sender, founderAddress, founderFee);
            totalFounderRewards += founderFee;

            _transfer(msg.sender, stakingPool, stakingFee);
            totalStakingRewards += stakingFee;

            _burn(msg.sender, burnAmount);
            totalBurned += burnAmount;

            totalBytesProcessed += _byteSizes[i];
            totalMessagesProcessed += 1;

            emit MessageProcessed(
                msg.sender,
                _recipients[i],
                _byteSizes[i],
                _dataTypes[i],
                totalCost,
                nodeFee,
                founderFee,
                stakingFee,
                burnAmount,
                block.timestamp
            );
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // NODE MANAGEMENT
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Registra um node como autorizado para processar mensagens
     * @param _node Endereço do node
     */
    function registerNode(address _node) external onlyOwner {
        require(_node != address(0), "DChatToken: node is zero address");
        require(!authorizedNodes[_node], "DChatToken: node already registered");

        authorizedNodes[_node] = true;
        nodeCount += 1;

        emit NodeRegistered(_node, block.timestamp);
    }

    /**
     * @notice Remove um node da lista de autorizados
     * @param _node Endereço do node
     */
    function removeNode(address _node) external onlyOwner {
        require(authorizedNodes[_node], "DChatToken: node not registered");

        authorizedNodes[_node] = false;
        nodeCount -= 1;

        emit NodeRemoved(_node, block.timestamp);
    }

    /**
     * @notice FIX M-02: Permite ao owner transferir recompensas pendentes de nodes removidos
     * @dev Nodes removidos não podem chamar claimNodeRewards() diretamente (requer onlyAuthorizedNode).
     *      Esta função garante que tokens não fiquem permanentemente travados no contrato.
     * @param _node Endereço do node removido
     */
    function claimRewardsForRemovedNode(address _node) external onlyOwner nonReentrant {
        require(!authorizedNodes[_node], "DChatToken: node still active, use claimNodeRewards");
        uint256 rewards = pendingNodeRewards[_node];
        require(rewards > 0, "DChatToken: no pending rewards for this node");

        pendingNodeRewards[_node] = 0;
        _transfer(address(this), _node, rewards);

        emit RemovedNodeRewardClaimed(_node, rewards, block.timestamp);
    }

    /**
     * @notice Permite que um node autorizado resgate suas recompensas pendentes
     */
    function claimNodeRewards() external onlyAuthorizedNode nonReentrant {
        uint256 rewards = pendingNodeRewards[msg.sender];
        require(rewards > 0, "DChatToken: no pending rewards");

        pendingNodeRewards[msg.sender] = 0;
        _transfer(address(this), msg.sender, rewards);

        emit NodeRewardClaimed(msg.sender, rewards, block.timestamp);
    }

    /**
     * @notice Registra múltiplos nodes em batch
     * @param _nodes Array de endereços dos nodes
     */
    function registerNodeBatch(address[] calldata _nodes) external onlyOwner {
        // FIX L-02: Limite máximo de nodes por batch para evitar out-of-gas
        require(_nodes.length <= 100, "DChatToken: batch too large, max 100 nodes");
        for (uint256 i = 0; i < _nodes.length; i++) {
            if (_nodes[i] != address(0) && !authorizedNodes[_nodes[i]]) {
                authorizedNodes[_nodes[i]] = true;
                nodeCount += 1;
                emit NodeRegistered(_nodes[i], block.timestamp);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // FOUNDER VESTING
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Calcula tokens disponíveis para claim pelo fundador (vesting linear)
     * @return Quantidade de tokens disponíveis
     */
    function founderVestingAvailable() public view returns (uint256) {
        if (block.timestamp < founderVestingStart) return 0;

        uint256 elapsed = block.timestamp - founderVestingStart;
        if (elapsed >= founderVestingDuration) {
            return founderTotalVesting - founderTokensClaimed;
        }

        uint256 totalVested = (founderTotalVesting * elapsed) / founderVestingDuration;
        return totalVested - founderTokensClaimed;
    }

    /**
     * @notice Permite ao fundador resgatar tokens vested
     */
    function claimFounderVesting() external nonReentrant {
        require(msg.sender == founderAddress, "DChatToken: not founder");

        uint256 available = founderVestingAvailable();
        require(available > 0, "DChatToken: no tokens available");

        founderTokensClaimed += available;
        _transfer(address(this), founderAddress, available);

        emit FounderVestingClaimed(founderAddress, available, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════
    // GOVERNANCE / ADMIN
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Atualiza o custo por byte
     * @param _newCostPerByte Novo custo em wei de DCHAT
     */
    /// @notice Limite máximo para costPerByte (FIX L-01)
    uint256 public constant MAX_COST_PER_BYTE = 1e15;

    function setCostPerByte(uint256 _newCostPerByte) external onlyOwner {
        require(_newCostPerByte > 0 && _newCostPerByte <= MAX_COST_PER_BYTE, "DChatToken: cost must be > 0 and <= MAX_COST_PER_BYTE");
        uint256 oldCost = costPerByte;
        costPerByte = _newCostPerByte;
        emit CostPerByteUpdated(oldCost, _newCostPerByte);
    }

    /**
     * @notice Atualiza o multiplicador de um tipo de dado
     * @param _dataType Tipo de dado
     * @param _multiplier Novo multiplicador (10000 = 1.0x)
     */
    function setDataTypeMultiplier(uint8 _dataType, uint256 _multiplier) external onlyOwner {
        require(_multiplier > 0, "DChatToken: multiplier must be > 0");
        uint256 oldMultiplier = dataTypeMultiplier[_dataType];
        dataTypeMultiplier[_dataType] = _multiplier;
        emit DataTypeMultiplierUpdated(_dataType, oldMultiplier, _multiplier);
    }

    /**
     * @notice Atualiza o endereço do staking pool
     * @param _newStakingPool Novo endereço
     */
    function setStakingPool(address _newStakingPool) external onlyOwner {
        require(_newStakingPool != address(0), "DChatToken: staking pool is zero address");
        address oldPool = stakingPool;
        stakingPool = _newStakingPool;
        emit StakingPoolUpdated(oldPool, _newStakingPool);
    }

    /**
     * @notice Ativa/desativa modo de emergência
     */
    function toggleEmergencyMode() external onlyOwner {
        emergencyMode = !emergencyMode;
        emit EmergencyModeToggled(emergencyMode, block.timestamp);
    }

    /**
     * @notice Pausa o contrato (OpenZeppelin Pausable)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Despausa o contrato
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ═══════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Retorna métricas globais da rede
     */
    function getNetworkStats()
        external
        view
        returns (
            uint256 _totalBytesProcessed,
            uint256 _totalMessagesProcessed,
            uint256 _totalBurned,
            uint256 _totalNodeRewards,
            uint256 _totalFounderRewards,
            uint256 _totalStakingRewards,
            uint256 _nodeCount,
            uint256 _currentCostPerByte,
            uint256 _circulatingSupply
        )
    {
        return (
            totalBytesProcessed,
            totalMessagesProcessed,
            totalBurned,
            totalNodeRewards,
            totalFounderRewards,
            totalStakingRewards,
            nodeCount,
            costPerByte,
            totalSupply() // Já desconta os tokens queimados
        );
    }

    /**
     * @notice Retorna informações de vesting do fundador
     */
    function getFounderVestingInfo()
        external
        view
        returns (
            uint256 _totalVesting,
            uint256 _claimed,
            uint256 _available,
            uint256 _vestingEnd
        )
    {
        return (
            founderTotalVesting,
            founderTokensClaimed,
            founderVestingAvailable(),
            founderVestingStart + founderVestingDuration
        );
    }
}
