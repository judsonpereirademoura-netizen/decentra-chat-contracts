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


// File @openzeppelin/contracts/interfaces/draft-IERC6093.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
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


// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File @openzeppelin/contracts/token/ERC20/ERC20.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.20;




/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}


// File @openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol@v5.0.2

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys a `value` amount of tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, deducting from
     * the caller's allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `value`.
     */
    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
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


// File contracts/DChatStablecoin.sol

pragma solidity ^0.8.24;






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
    ) external nonReentrant whenNotPaused {
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
