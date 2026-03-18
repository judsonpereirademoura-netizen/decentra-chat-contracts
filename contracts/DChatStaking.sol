// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title DChatStaking
 * @author DecentraChat — Judson Moura
 * @notice Contrato de staking do $DCHAT. Usuários fazem stake de tokens e recebem
 *         recompensas proporcionais alimentadas pelo staking pool (10% das taxas de mensagem).
 *
 * Modelo de Recompensa:
 *   - Recompensas são distribuídas proporcionalmente ao stake de cada usuário
 *   - Utiliza o padrão "reward per token stored" para cálculo eficiente
 *   - Período mínimo de lock: 7 dias (configurável)
 *   - Sem penalidade por unstake após o período de lock
 *
 * Nota Jurídica:
 *   As recompensas de staking são classificadas como "recompensa por serviço prestado
 *   à rede" (validação e relay de mensagens), e não como rendimento passivo sobre capital
 *   investido, conforme recomendação da análise jurídica para evitar enquadramento como
 *   contrato de investimento coletivo pela CVM.
 */
contract DChatStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Token $DCHAT
    IERC20 public immutable dchatToken;

    /// @notice Período mínimo de lock (padrão: 7 dias)
    uint256 public lockPeriod;

    /// @notice Total de tokens em stake
    uint256 public totalStaked;

    /// @notice Reward per token stored (acumulado)
    uint256 public rewardPerTokenStored;

    /// @notice Último timestamp de atualização de recompensas
    uint256 public lastUpdateTime;

    /// @notice Total de recompensas distribuídas
    uint256 public totalRewardsDistributed;

    /// @notice Total de recompensas pendentes no contrato
    uint256 public totalRewardsPending;

    // ═══════════════════════════════════════════════════════════════
    // STRUCTS
    // ═══════════════════════════════════════════════════════════════

    struct StakeInfo {
        uint256 amount;           // Quantidade em stake
        uint256 stakeTimestamp;   // Quando fez stake
        uint256 rewardDebt;       // Reward per token no momento do stake
        uint256 pendingRewards;   // Recompensas acumuladas
    }

    // ═══════════════════════════════════════════════════════════════
    // MAPPINGS
    // ═══════════════════════════════════════════════════════════════

    mapping(address => StakeInfo) public stakes;

    // ═══════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════

    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event RewardsDeposited(uint256 amount, uint256 timestamp);
    event LockPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);
    event TokensRecovered(address indexed token, uint256 amount, uint256 timestamp);

    // ═══════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /**
     * @param _dchatToken Endereço do contrato DChatToken
     * @param _lockPeriod Período mínimo de lock em segundos
     */
    constructor(
        address _dchatToken,
        uint256 _lockPeriod
    ) Ownable(msg.sender) {
        require(_dchatToken != address(0), "DChatStaking: token is zero address");

        dchatToken = IERC20(_dchatToken);
        lockPeriod = _lockPeriod;
        lastUpdateTime = block.timestamp;
    }

    // ═══════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @dev Atualiza as recompensas acumuladas para um usuário
     */
    function _updateRewards(address _user) internal {
        if (totalStaked > 0 && totalRewardsPending > 0) {
            // Calcular novas recompensas desde a última atualização
            uint256 newRewardPerToken = rewardPerTokenStored +
                (totalRewardsPending * 1e18) / totalStaked;
            rewardPerTokenStored = newRewardPerToken;
            totalRewardsPending = 0;
        }

        lastUpdateTime = block.timestamp;

        if (_user != address(0)) {
            StakeInfo storage userStake = stakes[_user];
            if (userStake.amount > 0) {
                uint256 earned = (userStake.amount * (rewardPerTokenStored - userStake.rewardDebt)) / 1e18;
                userStake.pendingRewards += earned;
            }
            userStake.rewardDebt = rewardPerTokenStored;
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // CORE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Faz stake de tokens $DCHAT
     * @param _amount Quantidade de tokens para stake
     */
    function stake(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount > 0, "DChatStaking: amount must be > 0");

        _updateRewards(msg.sender);

        dchatToken.safeTransferFrom(msg.sender, address(this), _amount);

        StakeInfo storage userStake = stakes[msg.sender];

        // FIX M-01: Média ponderada do timestamp para não resetar lock de tokens existentes
        if (userStake.amount > 0) {
            // Weighted average: preserva o progresso do lock existente
            uint256 existingWeight = userStake.amount * userStake.stakeTimestamp;
            uint256 newWeight = _amount * block.timestamp;
            userStake.stakeTimestamp = (existingWeight + newWeight) / (userStake.amount + _amount);
        } else {
            userStake.stakeTimestamp = block.timestamp;
        }

        userStake.amount += _amount;

        totalStaked += _amount;

        emit Staked(msg.sender, _amount, block.timestamp);
    }

    /**
     * @notice Remove tokens do stake
     * @param _amount Quantidade de tokens para remover
     */
    function unstake(uint256 _amount) external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= _amount, "DChatStaking: insufficient stake");
        require(
            block.timestamp >= userStake.stakeTimestamp + lockPeriod,
            "DChatStaking: lock period not expired"
        );

        _updateRewards(msg.sender);

        userStake.amount -= _amount;
        totalStaked -= _amount;

        dchatToken.safeTransfer(msg.sender, _amount);

        emit Unstaked(msg.sender, _amount, block.timestamp);
    }

    /**
     * @notice Resgata recompensas acumuladas
     */
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);

        StakeInfo storage userStake = stakes[msg.sender];
        uint256 rewards = userStake.pendingRewards;
        require(rewards > 0, "DChatStaking: no rewards to claim");

        userStake.pendingRewards = 0;
        totalRewardsDistributed += rewards;

        dchatToken.safeTransfer(msg.sender, rewards);

        emit RewardClaimed(msg.sender, rewards, block.timestamp);
    }

    /**
     * @notice Deposita recompensas no pool (chamado pelo DChatToken ao processar mensagens)
     * @param _amount Quantidade de tokens de recompensa
     */
    function depositRewards(uint256 _amount) external {
        require(_amount > 0, "DChatStaking: amount must be > 0");

        dchatToken.safeTransferFrom(msg.sender, address(this), _amount);
        totalRewardsPending += _amount;

        emit RewardsDeposited(_amount, block.timestamp);
    }

    // ═══════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Retorna informações de stake de um usuário
     */
    function getStakeInfo(address _user)
        external
        view
        returns (
            uint256 stakedAmount,
            uint256 pendingRewards,
            uint256 stakeTimestamp,
            uint256 unlockTimestamp,
            bool isLocked
        )
    {
        StakeInfo storage userStake = stakes[_user];

        // Calcular recompensas pendentes (view, sem alterar estado)
        uint256 currentRewardPerToken = rewardPerTokenStored;
        if (totalStaked > 0 && totalRewardsPending > 0) {
            currentRewardPerToken += (totalRewardsPending * 1e18) / totalStaked;
        }

        uint256 earned = 0;
        if (userStake.amount > 0) {
            earned = (userStake.amount * (currentRewardPerToken - userStake.rewardDebt)) / 1e18;
        }

        uint256 unlock = userStake.stakeTimestamp + lockPeriod;

        return (
            userStake.amount,
            userStake.pendingRewards + earned,
            userStake.stakeTimestamp,
            unlock,
            block.timestamp < unlock
        );
    }

    /**
     * @notice Retorna métricas globais do staking
     */
    function getStakingStats()
        external
        view
        returns (
            uint256 _totalStaked,
            uint256 _totalRewardsDistributed,
            uint256 _totalRewardsPending,
            uint256 _lockPeriod,
            uint256 _stakingBalance
        )
    {
        return (
            totalStaked,
            totalRewardsDistributed,
            totalRewardsPending,
            lockPeriod,
            dchatToken.balanceOf(address(this))
        );
    }

    /**
     * @notice Calcula APY estimado baseado nas recompensas recentes
     * @return APY em basis points (10000 = 100%)
     */
    function estimatedAPY() external view returns (uint256) {
        if (totalStaked == 0) return 0;

        // FIX L-03: Janela mínima de 1 hora para evitar APY inflado
        uint256 elapsed = block.timestamp - lastUpdateTime;
        if (elapsed < 1 hours) return 0;

        uint256 rewardRate = (totalRewardsPending * 365 days) / elapsed;
        return (rewardRate * 10_000) / totalStaked;
    }

    // ═══════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /**
     * @notice Atualiza o período de lock
     * @param _newLockPeriod Novo período em segundos
     */
    function setLockPeriod(uint256 _newLockPeriod) external onlyOwner {
        uint256 oldPeriod = lockPeriod;
        lockPeriod = _newLockPeriod;
        emit LockPeriodUpdated(oldPeriod, _newLockPeriod);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Recupera tokens enviados por engano (exceto DCHAT em stake)
     * @param _token Endereço do token a recuperar
     * @param _amount Quantidade
     */
    function recoverTokens(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(dchatToken)) {
            // Só permite recuperar excesso (não os tokens em stake)
            uint256 excess = dchatToken.balanceOf(address(this)) - totalStaked - totalRewardsPending;
            require(_amount <= excess, "DChatStaking: cannot recover staked tokens");
        }
        IERC20(_token).safeTransfer(owner(), _amount);

        // FIX L-04: Emitir evento para rastreamento on-chain
        emit TokensRecovered(_token, _amount, block.timestamp);
    }
}
