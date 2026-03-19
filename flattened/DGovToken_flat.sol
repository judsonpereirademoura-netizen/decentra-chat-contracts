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


// File contracts/DGovToken.sol

pragma solidity ^0.8.24;





}

/**
 * @title DGovToken ($DGOV) v3.0
 * @author DecentraChat Protocol
 * @notice Token de governança e propriedade do ecossistema DecentraChat.
 *
 *   ALOCAÇÃO DO SUPPLY (100M):
 *     - 30% Fundador (30M) — vesting 10M a cada 12 meses, recebe dividendos desde dia 1
 *     - 10% Marketing (10M) — liberado ao fundador, lock 180 dias por transferência a prestadores
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
contract DGovToken is ERC20, AccessControl, ReentrancyGuard, Pausable {

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

    uint256 public constant MAX_BIDS_PER_AUCTION = 100;  // [SA-02] Reduzido de 500→100 para evitar DoS por gas no sorting O(n²)
    uint256 public constant MAX_ANTI_SNIPE_EXTENSIONS = 6; // [F-03] Máximo 1h extra de extensão

    uint256 public constant VESTING_TRANCHES = 3;
    uint256 public constant VESTING_INTERVAL = 365 days;
    uint256 public constant FOUNDER_PER_TRANCHE = 10_000_000 * 1e18;

    // Marketing: 180 dias de lock total + 180 dias de liberação linear gradual
    uint256 public constant MARKETING_LOCK_PERIOD = 180 days;
    uint256 public constant MARKETING_VESTING_PERIOD = 180 days;

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

    // Marketing: tokens transferidos pelo fundador para prestadores
    // 180 dias de lock total + 180 dias de liberação linear gradual
    struct MarketingLock {
        uint256 amount;        // Total de tokens no lock
        uint256 lockEnd;       // Fim do lock total (180 dias após transferência)
        uint256 vestingEnd;    // Fim do vesting linear (360 dias após transferência)
        uint256 claimed;       // Tokens já liberados/claimed do vesting
    }
    mapping(address => MarketingLock[]) public marketingLocks;
    mapping(address => uint256) public marketingLockedCache; // [F-04] Cache de locked por endereço
    uint256 public totalMarketingDistributed;  // Total já distribuído pelo fundador
    uint256 public totalMarketingLocked;       // Total atualmente locked em prestadores

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
        uint256 antiSnipeCount;      // [F-03] Contador de extensões anti-sniping
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public auctionBids; // auctionId => array de bids
    mapping(uint256 => mapping(address => uint256[])) public userBidIndices; // auctionId => user => bid indices

    uint256 public currentAuctionId;
    uint256 public auctionsStartTime;
    uint256 public totalTokensBurned;
    uint256 public totalAuctionRevenue;

    // Governance is handled by a separate DGovGovernance contract
    address public governanceContract;

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
    event DividendPoolUpdated(address indexed oldPool, address indexed newPool); // [SA-07]

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
        require(users.length <= 200, "Batch too large"); // [F-06]
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
    // MARKETING DISTRIBUTION (10M: fundador transfere para prestadores com lock 180 dias)
    // =========================================================================

    /**
     * @notice Fundador transfere tokens de marketing para um prestador de serviço.
     *         Os tokens ficam locked na carteira do prestador por 180 dias.
     * @param recipient Endereço do prestador de serviço
     * @param amount Quantidade de $DGOV a transferir
     */
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

        // Transfer tokens from contract to recipient (locked)
        _transfer(address(this), recipient, amount);

        // Create lock entry: 180d lock + 180d linear vesting
        uint256 lockEnd = block.timestamp + MARKETING_LOCK_PERIOD;
        uint256 vestingEnd = lockEnd + MARKETING_VESTING_PERIOD;
        uint256 lockIndex = marketingLocks[recipient].length;
        marketingLocks[recipient].push(MarketingLock({
            amount: amount,
            lockEnd: lockEnd,
            vestingEnd: vestingEnd,
            claimed: 0
        }));

        // [F-04] Atualizar cache
        marketingLockedCache[recipient] += amount;

        emit MarketingTokensTransferred(recipient, amount, lockEnd, lockIndex);
    }

    /**
     * @notice Prestador faz claim dos tokens liberados pelo vesting linear.
     *         Após 180 dias de lock, inicia liberação linear por mais 180 dias.
     * @param lockIndex Índice do lock a fazer claim
     */
    function unlockMarketingVesting(uint256 lockIndex) external nonReentrant { // [F-05] Renamed for clarity
        require(lockIndex < marketingLocks[msg.sender].length, "Invalid lock index");

        MarketingLock storage lock = marketingLocks[msg.sender][lockIndex];
        require(block.timestamp >= lock.lockEnd, "Lock period not expired");

        uint256 vested = _getVestedAmount(lock);
        uint256 claimable = vested - lock.claimed;
        require(claimable > 0, "Nothing to claim");

        lock.claimed += claimable;
        totalMarketingLocked -= claimable;

        // [F-04] Atualizar cache
        if (marketingLockedCache[msg.sender] >= claimable) {
            marketingLockedCache[msg.sender] -= claimable;
        } else {
            marketingLockedCache[msg.sender] = 0;
        }

        emit MarketingTokensUnlocked(msg.sender, lockIndex, claimable);
    }

    /**
     * @notice Calcula a quantidade total já vested (liberada) de um lock.
     */
    function _getVestedAmount(MarketingLock storage lock) internal view returns (uint256) {
        if (block.timestamp < lock.lockEnd) return 0;
        if (block.timestamp >= lock.vestingEnd) return lock.amount;

        // Linear vesting: proporcional ao tempo decorrido no período de vesting
        uint256 elapsed = block.timestamp - lock.lockEnd;
        return (lock.amount * elapsed) / MARKETING_VESTING_PERIOD;
    }

    /**
     * @notice Override de transfer para impedir transferência de tokens locked de marketing.
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        if (from != address(0) && from != address(this)) {
            // [F-04] Usa cache para evitar iteração O(n) em cada transfer
            uint256 lockedAmount = marketingLockedCache[from];
            if (lockedAmount > 0) {
                // Recalcular cache se necessário (vesting pode ter liberado tokens)
                lockedAmount = getMarketingLockedBalance(from);
                marketingLockedCache[from] = lockedAmount;
            }
            uint256 balance = balanceOf(from);
            require(balance - lockedAmount >= value, "Cannot transfer locked marketing tokens");
        }
        super._update(from, to, value);
    }

    /**
     * @notice Retorna o total de tokens de marketing ainda locked para um endereço.
     */
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

    /**
     * @notice Retorna quanto um prestador pode fazer claim agora.
     */
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

    /**
     * @notice Retorna informações sobre os locks de marketing de um endereço.
     */
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

    /**
     * @notice Dar um lance fracionado no leilão ativo.
     * @param quantity Quantidade de $DGOV desejada
     * @param pricePerUnit Preço por unidade em $DCHAT (18 decimals)
     */
    function placeBid(uint256 quantity, uint256 pricePerUnit) external nonReentrant whenNotPaused {
        require(registeredUsers[msg.sender], "Not a registered user");

        uint256 auctionId = currentAuctionId;
        Auction storage auction = auctions[auctionId];

        require(auctionId > 0, "No active auction");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(!auction.finalized, "Auction finalized");
        require(auctionBids[auctionId].length < MAX_BIDS_PER_AUCTION, "Max bids reached for this auction"); // [F-01/F-02]
        require(quantity > 0, "Quantity must be > 0");
        require(pricePerUnit > 0, "Price must be > 0");

        // Enforce minimum price: 0.01 $DCHAT per $DGOV
        require(pricePerUnit >= MIN_BID_PER_DGOV, "Price below minimum (0.01 DCHAT/DGOV)");

        // [F-07] Enforce 5% increment: se o bid quer superar o highest price atual,
        // deve ser pelo menos 5% maior. Bids abaixo ou iguais ao highest são permitidos
        // (serão preenchidos normalmente do maior ao menor na finalização).
        if (auction.highestPricePerUnit > 0 && pricePerUnit > auction.highestPricePerUnit) {
            uint256 minIncrement = (auction.highestPricePerUnit * 105) / 100; // 5% acima
            require(pricePerUnit >= minIncrement, "New highest bid must be >= 5% above current highest");
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

        // Anti-sniping: extend auction if bid in last 10 minutes [F-03: limited extensions]
        if (auction.endTime - block.timestamp <= ANTI_SNIPE_WINDOW
            && auction.antiSnipeCount < MAX_ANTI_SNIPE_EXTENSIONS) {
            auction.endTime += ANTI_SNIPE_EXTENSION;
            auction.antiSnipeCount++;
            emit AuctionExtended(auctionId, auction.endTime);
        }

        emit BidPlaced(auctionId, msg.sender, quantity, pricePerUnit, totalCost, bidIndex);
    }

    /**
     * @notice Finalizar um leilão — ordena bids do maior preço ao menor,
     *         preenche até esgotar o lote, devolve excedentes, queima sobras,
     *         envia 100% da receita ao DividendPool.
     */
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
            require(
                IERC20(dchatToken).transfer(dividendPool, totalRevenueLocal),
                "Dividend transfer failed"
            );
            // [AUTO-03] Notificar DividendPool automaticamente para atualizar pointsPerToken
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
    // [F-14] CIRCUIT BREAKER — PAUSE/UNPAUSE
    // =========================================================================

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // =========================================================================
    // TOKEN QUERY HELPERS (used by DGovGovernance contract)
    // =========================================================================

    /**
     * @notice Total de $DGOV emitidos (não queimados). Base para quorum e threshold.
     */
    function getTotalEmitted() public view returns (uint256) {
        return TOTAL_SUPPLY - totalTokensBurned;
    }

    /**
     * @notice Retorna o peso de vesting de um holder (tokens locked que contam para voto).
     *         Founder: tokens não-claimed do vesting. Marketing: tokens locked.
     */
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
        emit DividendPoolUpdated(oldPool, _pool); // [SA-07]
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
        uint256 marketingRemaining = MARKETING_ALLOCATION - totalMarketingDistributed;
        return founderRemaining + marketingRemaining;
    }
}
