// Sources flattened with hardhat v2.28.6 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/access/IAccessControl.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (access/IAccessControl.sol)

pragma solidity ^0.8.20;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}


// File @openzeppelin/contracts/utils/Context.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// File @openzeppelin/contracts/utils/introspection/IERC165.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File @openzeppelin/contracts/utils/introspection/ERC165.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File @openzeppelin/contracts/access/AccessControl.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (access/AccessControl.sol)

pragma solidity ^0.8.20;



/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}


// File @openzeppelin/contracts/utils/Pausable.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// File contracts/DividendPool.sol

pragma solidity ^0.8.24;




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
     * @dev [SA-12] DEPRECATED: Com F-17, o vesting weight é calculado automaticamente
     *      via DGovToken.getVestingWeight(). Esta função é mantida apenas como
     *      fallback de emergência. O sistema usa max(auto, manual) para segurança.
     *      Tokens em vesting contam para dividendos desde dia 1.
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
     * @dev [SA-12] DEPRECATED: Com F-17, o vesting weight é atualizado automaticamente.
     *      Mantida como fallback de emergência.
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
    /**
     * @dev [F-17] Agora consulta automaticamente o DGovToken.getVestingWeight()
     *      ao invés de depender de vestingWeight manual.
     *      Fallback: se o DGovToken retornar 0 mas houver vestingWeight manual, usa o manual.
     */
    function getHolderWeight(address holder) public view returns (uint256) {
        uint256 balance = dgovToken.balanceOf(holder);
        // [F-17] Consulta automática do vesting weight do DGovToken
        uint256 autoWeight = dgovToken.getVestingWeight(holder);
        uint256 manualWeight = vestingWeight[holder];
        // Usa o maior entre automático e manual (para retrocompatibilidade)
        uint256 effectiveWeight = autoWeight > manualWeight ? autoWeight : manualWeight;
        return balance + effectiveWeight;
    }

    /**
     * @notice Get the total dividend weight across all holders.
     */
    function _getTotalDividendWeight() internal view returns (uint256) {
        // [F-15] Descontar tokens inativos no contrato DGovToken
        // [F-17] Agora calcula vesting weight automático:
        //   - Founder: FOUNDER_ALLOCATION - tokens já claimed (via getVestingWeight)
        //   - Marketing: totalMarketingDistributed (tokens locked com prestadores)
        // Fórmula: circulatingSupply + max(autoVestingTotal, manualTotalVestingWeight)
        uint256 circulatingSupply = dgovToken.totalSupply() - dgovToken.balanceOf(dgovTokenAddress);
        
        // Calcular vesting weight automático total
        // Founder vesting weight
        uint256 founderAutoWeight = dgovToken.getVestingWeight(dgovToken.founder());
        // [SA-05] Marketing: APENAS tokens ainda locked (não os já unlocked que estão no balanceOf)
        uint256 marketingAutoWeight = dgovToken.totalMarketingLocked();
        uint256 autoTotal = founderAutoWeight + marketingAutoWeight;
        
        // Usa o maior entre automático e manual (retrocompatibilidade)
        uint256 effectiveTotalVesting = autoTotal > totalVestingWeight ? autoTotal : totalVestingWeight;
        return circulatingSupply + effectiveTotalVesting;
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
