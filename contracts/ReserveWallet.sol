// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ReserveWallet
 * @author DecentraChat Protocol
 * @notice Carteira de reserva operacional do protocolo DecentraChat.
 *         REGRA FUNDAMENTAL: Esta carteira SÓ pode ser usada para pagar
 *         despesas operacionais da plataforma. Cada saque é registrado
 *         on-chain com categoria, descrição e valor para total transparência.
 *
 * @dev Categorias de despesa permitidas:
 *   0 = HOSTING     — Servidores, CDN, domínios, cloud
 *   1 = SMS_TWILIO  — Verificação de telefone via Twilio
 *   2 = INFRA       — Infraestrutura de rede, nodes, hardware
 *   3 = MARKETING   — Campanhas, ads, parcerias (limitado)
 *   4 = LEGAL       — Jurídico, compliance, regulatório
 *   5 = EMERGENCY   — Despesas emergenciais (requer justificativa)
 *
 *   Regras:
 *   - Limite mensal de saque por categoria
 *   - Cada saque emite evento público com justificativa
 *   - Histórico completo auditável on-chain
 *   - Admin pode ajustar limites (com evento)
 *   - Qualquer pessoa pode consultar gastos por categoria
 */
contract ReserveWallet is AccessControl, ReentrancyGuard {

    // =========================================================================
    // ROLES
    // =========================================================================
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // =========================================================================
    // EXPENSE CATEGORIES
    // =========================================================================
    enum ExpenseCategory {
        HOSTING,        // 0 — Servidores, CDN, domínios
        SMS_TWILIO,     // 1 — Verificação de telefone
        INFRA,          // 2 — Infraestrutura de rede
        MARKETING,      // 3 — Campanhas e parcerias
        LEGAL,          // 4 — Jurídico e compliance
        EMERGENCY       // 5 — Despesas emergenciais
    }

    uint8 public constant CATEGORY_COUNT = 6;

    // =========================================================================
    // MONTHLY LIMITS (in $DCHAT, 18 decimals)
    // =========================================================================
    mapping(uint8 => uint256) public monthlyLimit;
    mapping(uint8 => mapping(uint256 => uint256)) public monthlySpent; // category => month => spent

    // Default monthly limits
    uint256 public constant DEFAULT_HOSTING_LIMIT = 5_000 * 1e18;      // $5,000/mês
    uint256 public constant DEFAULT_SMS_LIMIT = 2_000 * 1e18;           // $2,000/mês
    uint256 public constant DEFAULT_INFRA_LIMIT = 3_000 * 1e18;         // $3,000/mês
    uint256 public constant DEFAULT_MARKETING_LIMIT = 1_000 * 1e18;     // $1,000/mês
    uint256 public constant DEFAULT_LEGAL_LIMIT = 2_000 * 1e18;         // $2,000/mês
    uint256 public constant DEFAULT_EMERGENCY_LIMIT = 5_000 * 1e18;     // $5,000/mês

    // Total monthly cap across all categories
    uint256 public totalMonthlyCap = 18_000 * 1e18; // $18,000/mês total

    // =========================================================================
    // EXPENSE RECORDS
    // =========================================================================
    struct Expense {
        uint256 id;
        uint8 category;
        uint256 amount;
        address recipient;
        string description;
        uint256 timestamp;
        address approvedBy;
    }

    Expense[] public expenses;
    uint256 public totalExpenses;

    // Per-category totals (all time)
    mapping(uint8 => uint256) public totalSpentByCategory;
    uint256 public totalSpentAllTime;

    // =========================================================================
    // TOKEN
    // =========================================================================
    IERC20 public dchatToken;

    // =========================================================================
    // ADMIN TRANSFER (2-step)
    // =========================================================================
    address public admin;
    address public pendingAdmin;
    uint256 public adminTransferInitiated;
    uint256 public constant ADMIN_TRANSFER_DELAY = 48 hours;

    // =========================================================================
    // EVENTS
    // =========================================================================
    event ExpenseRecorded(
        uint256 indexed expenseId,
        uint8 indexed category,
        uint256 amount,
        address indexed recipient,
        string description,
        address approvedBy,
        uint256 timestamp
    );

    event MonthlyLimitUpdated(
        uint8 indexed category,
        uint256 oldLimit,
        uint256 newLimit
    );

    event TotalMonthlyCapUpdated(uint256 oldCap, uint256 newCap);

    event AdminTransferInitiated(address indexed currentAdmin, address indexed pendingAdmin);
    event AdminTransferCompleted(address indexed oldAdmin, address indexed newAdmin);

    // =========================================================================
    // CONSTRUCTOR
    // =========================================================================
    constructor(address _admin, address _dchatToken) {
        require(_admin != address(0), "Invalid admin");
        require(_dchatToken != address(0), "Invalid token");

        admin = _admin;
        dchatToken = IERC20(_dchatToken);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);

        // Set default monthly limits
        monthlyLimit[uint8(ExpenseCategory.HOSTING)] = DEFAULT_HOSTING_LIMIT;
        monthlyLimit[uint8(ExpenseCategory.SMS_TWILIO)] = DEFAULT_SMS_LIMIT;
        monthlyLimit[uint8(ExpenseCategory.INFRA)] = DEFAULT_INFRA_LIMIT;
        monthlyLimit[uint8(ExpenseCategory.MARKETING)] = DEFAULT_MARKETING_LIMIT;
        monthlyLimit[uint8(ExpenseCategory.LEGAL)] = DEFAULT_LEGAL_LIMIT;
        monthlyLimit[uint8(ExpenseCategory.EMERGENCY)] = DEFAULT_EMERGENCY_LIMIT;
    }

    // =========================================================================
    // WITHDRAW — ONLY FOR OPERATIONAL EXPENSES
    // =========================================================================

    /**
     * @notice Withdraw $DCHAT for an operational expense.
     * @dev Each withdrawal is permanently recorded on-chain with full details.
     *      Subject to monthly limits per category and total monthly cap.
     * @param category The expense category (0-5)
     * @param amount Amount of $DCHAT to withdraw (18 decimals)
     * @param recipient Address to receive the $DCHAT
     * @param description Human-readable description of the expense
     */
    function withdraw(
        uint8 category,
        uint256 amount,
        address recipient,
        string calldata description
    ) external onlyRole(OPERATOR_ROLE) nonReentrant {
        require(category < CATEGORY_COUNT, "Invalid category");
        require(amount > 0, "Amount must be > 0");
        require(recipient != address(0), "Invalid recipient");
        require(bytes(description).length > 0, "Description required");
        require(bytes(description).length <= 500, "Description too long");

        uint256 currentMonth = _getCurrentMonth();

        // Check monthly limit for this category
        require(
            monthlySpent[category][currentMonth] + amount <= monthlyLimit[category],
            "Monthly category limit exceeded"
        );

        // Check total monthly cap
        uint256 totalThisMonth = _getTotalSpentThisMonth(currentMonth);
        require(
            totalThisMonth + amount <= totalMonthlyCap,
            "Total monthly cap exceeded"
        );

        // Check contract has sufficient balance
        require(
            dchatToken.balanceOf(address(this)) >= amount,
            "Insufficient reserve balance"
        );

        // Record expense BEFORE transfer (checks-effects-interactions)
        uint256 expenseId = expenses.length;
        expenses.push(Expense({
            id: expenseId,
            category: category,
            amount: amount,
            recipient: recipient,
            description: description,
            timestamp: block.timestamp,
            approvedBy: msg.sender
        }));

        monthlySpent[category][currentMonth] += amount;
        totalSpentByCategory[category] += amount;
        totalSpentAllTime += amount;
        totalExpenses++;

        // Transfer $DCHAT to recipient
        bool success = dchatToken.transfer(recipient, amount);
        require(success, "Transfer failed");

        emit ExpenseRecorded(
            expenseId, category, amount, recipient,
            description, msg.sender, block.timestamp
        );
    }

    // =========================================================================
    // ADMIN FUNCTIONS
    // =========================================================================

    function setMonthlyLimit(
        uint8 category,
        uint256 newLimit
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(category < CATEGORY_COUNT, "Invalid category");
        require(newLimit <= 50_000 * 1e18, "Limit too high"); // Max $50k/month per category
        uint256 oldLimit = monthlyLimit[category];
        monthlyLimit[category] = newLimit;
        emit MonthlyLimitUpdated(category, oldLimit, newLimit);
    }

    function setTotalMonthlyCap(uint256 newCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newCap <= 100_000 * 1e18, "Cap too high"); // Max $100k/month total
        uint256 oldCap = totalMonthlyCap;
        totalMonthlyCap = newCap;
        emit TotalMonthlyCapUpdated(oldCap, newCap);
    }

    // =========================================================================
    // ADMIN TRANSFER (2-step with timelock)
    // =========================================================================

    function initiateAdminTransfer(address _newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newAdmin != address(0), "Invalid address");
        require(_newAdmin != admin, "Already admin");
        pendingAdmin = _newAdmin;
        adminTransferInitiated = block.timestamp;
        emit AdminTransferInitiated(admin, _newAdmin);
    }

    function acceptAdminTransfer() external {
        require(msg.sender == pendingAdmin, "Not pending admin");
        require(adminTransferInitiated > 0, "No transfer initiated");
        require(
            block.timestamp >= adminTransferInitiated + ADMIN_TRANSFER_DELAY,
            "Timelock not expired"
        );

        address oldAdmin = admin;
        admin = pendingAdmin;

        // Transfer roles
        _grantRole(DEFAULT_ADMIN_ROLE, pendingAdmin);
        _grantRole(OPERATOR_ROLE, pendingAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, oldAdmin);
        _revokeRole(OPERATOR_ROLE, oldAdmin);

        pendingAdmin = address(0);
        adminTransferInitiated = 0;

        emit AdminTransferCompleted(oldAdmin, admin);
    }

    // =========================================================================
    // VIEW FUNCTIONS — PUBLIC AUDIT
    // =========================================================================

    /**
     * @notice Get the current reserve balance in $DCHAT.
     */
    function getBalance() external view returns (uint256) {
        return dchatToken.balanceOf(address(this));
    }

    /**
     * @notice Get spending summary for the current month.
     */
    function getCurrentMonthSummary() external view returns (
        uint256[6] memory categorySpent,
        uint256 totalSpent,
        uint256 remainingBudget
    ) {
        uint256 currentMonth = _getCurrentMonth();
        uint256 total = 0;
        for (uint8 i = 0; i < CATEGORY_COUNT; i++) {
            categorySpent[i] = monthlySpent[i][currentMonth];
            total += categorySpent[i];
        }
        totalSpent = total;
        remainingBudget = total < totalMonthlyCap ? totalMonthlyCap - total : 0;
    }

    /**
     * @notice Get spending for a specific category in a specific month.
     * @param category Expense category (0-5)
     * @param month Month identifier (year*12 + month)
     */
    function getMonthlySpending(uint8 category, uint256 month) external view returns (uint256) {
        return monthlySpent[category][month];
    }

    /**
     * @notice Get all-time spending summary by category.
     */
    function getAllTimeSpending() external view returns (
        uint256[6] memory categoryTotals,
        uint256 grandTotal
    ) {
        for (uint8 i = 0; i < CATEGORY_COUNT; i++) {
            categoryTotals[i] = totalSpentByCategory[i];
        }
        grandTotal = totalSpentAllTime;
    }

    /**
     * @notice Get expense details by ID.
     */
    function getExpense(uint256 expenseId) external view returns (
        uint8 category,
        uint256 amount,
        address recipient,
        string memory description,
        uint256 timestamp,
        address approvedBy
    ) {
        require(expenseId < expenses.length, "Invalid expense ID");
        Expense storage e = expenses[expenseId];
        return (e.category, e.amount, e.recipient, e.description, e.timestamp, e.approvedBy);
    }

    /**
     * @notice Get total number of recorded expenses.
     */
    function getExpenseCount() external view returns (uint256) {
        return expenses.length;
    }

    /**
     * @notice Get remaining budget for a specific category this month.
     */
    function getRemainingBudget(uint8 category) external view returns (uint256) {
        require(category < CATEGORY_COUNT, "Invalid category");
        uint256 currentMonth = _getCurrentMonth();
        uint256 spent = monthlySpent[category][currentMonth];
        uint256 limit = monthlyLimit[category];
        return spent < limit ? limit - spent : 0;
    }

    /**
     * @notice Get all monthly limits.
     */
    function getMonthlyLimits() external view returns (uint256[6] memory limits) {
        for (uint8 i = 0; i < CATEGORY_COUNT; i++) {
            limits[i] = monthlyLimit[i];
        }
    }

    // =========================================================================
    // INTERNAL FUNCTIONS
    // =========================================================================

    /**
     * @dev Calculate current month as year*12 + month for unique identification.
     */
    function _getCurrentMonth() internal view returns (uint256) {
        // Approximate: 30.44 days per month
        return block.timestamp / 30 days;
    }

    /**
     * @dev Get total spent across all categories for a given month.
     */
    function _getTotalSpentThisMonth(uint256 month) internal view returns (uint256) {
        uint256 total = 0;
        for (uint8 i = 0; i < CATEGORY_COUNT; i++) {
            total += monthlySpent[i][month];
        }
        return total;
    }
}
