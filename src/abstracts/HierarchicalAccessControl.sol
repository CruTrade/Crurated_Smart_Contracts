// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @dev Contract module that allows children to implement hierarchical role-based access
 * control mechanisms. This is a standalone implementation that provides role inheritance
 * where higher-level roles automatically have access to lower-level role functions.
 *
 * Roles are referred to by their `bytes32` identifier and assigned numeric levels.
 * Higher numbers represent higher privilege levels. For example:
 * - ADMIN_ROLE = 90 (high privilege)
 * - MODERATOR_ROLE = 80 (medium privilege)
 * - USER_ROLE = 70 (low privilege)
 *
 * Role inheritance works automatically: a user with ADMIN_ROLE can access functions
 * requiring MODERATOR_ROLE, but not vice versa.
 *
 * To restrict access to a function call, use the {onlyRole} modifier:
 *
 * ```solidity
 * function adminFunction() public onlyRole(ADMIN_ROLE) {
 *     // Only users with ADMIN_ROLE or higher can call this
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and {revokeRole}
 * functions. Each role has an associated admin role, and only accounts that have a
 * role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other roles.
 * 
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
contract HierarchicalAccessControl is
    Initializable,
    ContextUpgradeable,
    ERC165Upgradeable,
    IAccessControl
{
    /**
     * @dev Custom admin role for our hierarchical system.
     * This replaces the default OpenZeppelin admin role to work with our hierarchy.
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /**
     * @dev Storage structure for hierarchical access control data.
     * Uses ERC-7201 namespaced storage to prevent storage collisions.
     */
    /// @custom:storage-location erc7201:openzeppelin.storage.HierarchicalAccessControl
    struct HierarchicalAccessControlStorage {
        /**
         * @dev Mapping from role identifier to privilege level.
         * Higher numbers represent higher privilege levels.
         * Unknown roles default to level 0 (lowest privilege).
         */
        mapping(bytes32 => uint256) roleLevels;
        /**
         * @dev Mapping from account address to their assigned role.
         * Each account can have only one role, but higher roles inherit
         * permissions from lower roles through the hierarchy check.
         */
        mapping(address => bytes32) roleOf;
    }

    /**
     * @dev Storage location for hierarchical access control data.
     * Calculated using ERC-7201 namespace to avoid storage collisions.
     */
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.HierarchicalAccessControl")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HierarchicalAccessControlStorageLocation =
        0xa7366424ae217378dbcfb911918ed5f91d9e67652ee173a5a757a47f97b95e00;

    /**
     * @dev Returns the storage struct for hierarchical access control data.
     * Uses assembly to access the namespaced storage location.
     */
    function _getHierarchicalAccessControlStorage()
        private
        pure
        returns (HierarchicalAccessControlStorage storage $)
    {
        assembly {
            $.slot := HierarchicalAccessControlStorageLocation
        }
    }

    /**
     * @dev Initializes the hierarchical access control system.
     * Sets up role levels and initializes the base contracts.
     *
     * @notice This function should be called during contract initialization.
     * @dev Only callable during initialization phase.
     */
    function __HierarchicalAccessControl_init(address firstAdmin) internal initializer {
        __Context_init();
        __ERC165_init();

        HierarchicalAccessControlStorage
            storage $ = _getHierarchicalAccessControlStorage();

        // Set up default role levels
        $.roleLevels[ADMIN_ROLE] = 100;
        _grantRole(ADMIN_ROLE, firstAdmin);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IAccessControl).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override returns (bool) {
        return _safeCheckRole(role, account);
    }

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Overrides the base role checking function to implement hierarchical access control.
     *
     * The hierarchy check works as follows:
     * - If the required role level is GREATER than the user's role level, access is denied
     * - If the required role level is LESS THAN OR EQUAL to the user's role level, access is granted
     *
     * This means higher-level roles can access lower-level functions, but not vice versa.
     *
     * @param role The role identifier required for access
     * @param account The account to check for role access
     *
     * @dev This function is called by the {onlyRole} modifier and other access control functions.
     * @dev Unknown roles get level 0 (lowest privilege), which is safe.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!_safeCheckRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    function _safeCheckRole(bytes32 role, address account) internal view virtual returns (bool) {
        HierarchicalAccessControlStorage
            storage $ = _getHierarchicalAccessControlStorage();
        if ($.roleLevels[role] > $.roleLevels[$.roleOf[account]]) {
            return false;
        }
        return true;
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
    function grantRole(
        bytes32 role,
        address account
    ) public virtual override isAdminRoleFor(role) {
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
    function revokeRole(
        bytes32 role,
        address account
    ) public virtual override isAdminRoleFor(role) {
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
    function renounceRole(
        bytes32 role,
        address callerConfirmation
    ) public virtual override {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }
        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(
        bytes32 role,
        address account
    ) internal virtual returns (bool) {
        require(account != address(0), "Account cannot be zero address");
        HierarchicalAccessControlStorage
            storage $ = _getHierarchicalAccessControlStorage();
        if (!hasRole(role, account)) {
            $.roleOf[account] = role; // Update our hierarchical tracking
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
    function _revokeRole(
        bytes32 role,
        address account
    ) internal virtual returns (bool) {
        require(account != address(0), "Account cannot be zero address");
        HierarchicalAccessControlStorage
            storage $ = _getHierarchicalAccessControlStorage();
        if (hasRole(role, account)) {
            $.roleOf[account] = bytes32(0); // Clear our hierarchical tracking
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    modifier isAdminRoleFor(bytes32 role) {
        HierarchicalAccessControlStorage storage $ = _getHierarchicalAccessControlStorage();
        if (role == ADMIN_ROLE) {
            // Only allow if caller has ADMIN_ROLE
            if ($.roleOf[_msgSender()] != ADMIN_ROLE) {
                revert AccessControlUnauthorizedAccount(_msgSender(), role);
            }
            _;
            return;
        }
        if ($.roleLevels[role] >= $.roleLevels[$.roleOf[_msgSender()]]) {
            revert AccessControlUnauthorizedAccount(_msgSender(), role);
        }
        _;
    }

    /**
     * @dev Returns the privilege level for a given role.
     * @param role The role identifier
     * @return uint256 The privilege level (higher numbers = higher privileges)
     */
    function getRoleLevel(bytes32 role) public view returns (uint256) {
        HierarchicalAccessControlStorage
            storage $ = _getHierarchicalAccessControlStorage();
        return $.roleLevels[role];
    }

    /**
     * @dev Returns the assigned role for a given account.
     * @param account The account address
     * @return bytes32 The assigned role identifier
     */
    function getAccountRole(address account) public view returns (bytes32) {
        HierarchicalAccessControlStorage
            storage $ = _getHierarchicalAccessControlStorage();
        return $.roleOf[account];
    }

    /**
     * @dev Sets the privilege level for a role. Only callable by HIERARCHICAL_ADMIN_ROLE.
     * This allows dynamic role level management, useful for upgrades.
     *
     * @param role The role identifier to set the level for
     * @param level The new privilege level (higher numbers = higher privileges)
     *
     * @dev This function enables adding new roles or modifying existing role levels
     * @dev in upgrades without requiring storage migration.
     * @dev WARNING: Changing role levels can affect access control immediately.
     */
    function setRoleLevel(
        bytes32 role,
        uint256 level
    ) public onlyRole(ADMIN_ROLE) {
        _setRoleLevel(role, level);
    }

    function _setRoleLevel(
        bytes32 role,
        uint256 level
    ) internal {
        HierarchicalAccessControlStorage storage $ = _getHierarchicalAccessControlStorage();
        $.roleLevels[role] = level;
        emit RoleLevelSet(role, level);
    }

    /**
     * @dev Event emitted when a role level is set.
     * @param role The role identifier
     * @param level The privilege level set
     */
    event RoleLevelSet(bytes32 indexed role, uint256 level);


    function getRoleAdmin(
        bytes32
    ) external pure override returns (bytes32) {
        revert("Not implemented");
    }
}