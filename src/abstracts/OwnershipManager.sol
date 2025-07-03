// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./HierarchicalAccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @dev Contract module that provides ownership management functionality.
 * This contract ensures there's always exactly one owner and provides
 * secure ownership transfer mechanisms.
 *
 * The ownership system works as follows:
 * - There's always exactly one owner at any time
 * - The owner has the DEFAULT_ADMIN_ROLE (highest privilege)
 * - Ownership can only be transferred by the current owner
 * - The owner cannot renounce their role (ensures there's always an owner)
 * - Ownership transfer is atomic and protected against reentrancy
 *
 * This contract extends HierarchicalAccessControl to provide a complete
 * access control solution with hierarchical roles and ownership management.
 */
abstract contract OwnershipManager is 
    HierarchicalAccessControl, 
    ReentrancyGuardUpgradeable 
{
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The owner role is the DEFAULT_ADMIN_ROLE for compatibility
    bytes32 public constant OWNER_ROLE = ADMIN_ROLE;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Storage structure for ownership management data.
    /// Uses ERC-7201 namespaced storage to prevent storage collisions.
    /// @custom:storage-location erc7201:openzeppelin.storage.OwnershipManager
    struct OwnershipManagerStorage {
        /// @dev Current owner address
        address owner;
        /// @dev Flag to prevent reentrancy during ownership transfer
        bool transferringOwnership;
    }

    /// @dev Storage location for ownership management data.
    /// Calculated using ERC-7201 namespace to avoid storage collisions.
    /// keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.OwnershipManager")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OwnershipManagerStorageLocation = 0x8daad93a069f9e6a73dde9f1c9b2fc3be0b968d6097ec55c69b679102eca3900;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Thrown when attempting to grant the owner role
    error OwnerRoleCannotBeGranted();
    /// @dev Thrown when attempting to revoke the owner role
    error OwnerRoleCannotBeRevoked();
    /// @dev Thrown when attempting to transfer ownership to zero address
    error CannotTransferToZeroAddress();
    /// @dev Thrown when attempting to transfer ownership to self
    error CannotTransferToSelf();
    /// @dev Thrown when attempting to transfer ownership without being owner
    error OnlyOwnerCanTransfer();
    /// @dev Thrown when attempting to transfer ownership during another transfer
    error OwnershipTransferInProgress();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when ownership is transferred.
     * @param previousOwner The address of the previous owner
     * @param newOwner The address of the new owner
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier that checks if the caller is the owner.
     */
    modifier onlyOwner() {
        if (!isOwner(_msgSender())) {
            revert OnlyOwnerCanTransfer();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes the ownership management system.
     * Sets the initial owner and grants them the owner role.
     * 
     * @notice This function should be called during contract initialization.
     * @dev Only callable during initialization phase.
     */
    function __OwnershipManager_init(address _owner) internal initializer {
        __HierarchicalAccessControl_init(_owner);
        __ReentrancyGuard_init();
        
        setRoleLevel(OPERATOR_ROLE, 90);

        OwnershipManagerStorage storage $ = _getOwnershipManagerStorage();
        $.owner = _owner;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE ACCESS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Returns the storage struct for ownership management data.
     * Uses assembly to access the namespaced storage location.
     */
    function _getOwnershipManagerStorage() private pure returns (OwnershipManagerStorage storage $) {
        assembly {
            $.slot := OwnershipManagerStorageLocation
        }
    }

    /*//////////////////////////////////////////////////////////////
                                OWNERSHIP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Transfers ownership to a new account.
     * @param newOwner The address to transfer ownership to
     * 
     * @dev Only callable by the current owner
     * @dev Protected against reentrancy attacks
     * @dev Ensures there's always exactly one owner
     */
    function transferOwnership(address newOwner) public onlyOwner nonReentrant {
        if (newOwner == address(0)) {
            revert CannotTransferToZeroAddress();
        }
        
        OwnershipManagerStorage storage $ = _getOwnershipManagerStorage();
        address currentOwner = $.owner;
        
        if (newOwner == currentOwner) {
            revert CannotTransferToSelf();
        }
        
        if ($.transferringOwnership) {
            revert OwnershipTransferInProgress();
        }
        
        // Set flag to prevent reentrancy
        $.transferringOwnership = true;
        
        // Revoke owner role from current owner
        _revokeRole(OWNER_ROLE, currentOwner);
        
        // Grant owner role to new owner
        _grantRole(OWNER_ROLE, newOwner);
        
        // Update owner in storage
        $.owner = newOwner;
        
        // Clear flag
        $.transferringOwnership = false;
        
        emit OwnershipTransferred(currentOwner, newOwner);
    }

    /**
     * @dev Returns the current owner address.
     * @return address The current owner
     */
    function owner() public view returns (address) {
        OwnershipManagerStorage storage $ = _getOwnershipManagerStorage();
        return $.owner;
    }

    /**
     * @dev Returns true if the account has the owner role.
     * @param account The account to check
     * @return bool True if the account has the owner role
     */
    function isOwner(address account) public view returns (bool) {
        return hasRole(OWNER_ROLE, account);
    }

    /*//////////////////////////////////////////////////////////////
                                ROLE MANAGEMENT OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Overrides grantRole to prevent granting the owner role.
     * @param role The role identifier to grant
     * @param account The account to grant the role to
     */
    function grantRole(bytes32 role, address account) public override {
        if (role == OWNER_ROLE) {
            revert OwnerRoleCannotBeGranted();
        }
        super.grantRole(role, account);
    }

    /**
     * @dev Overrides revokeRole to prevent revoking the owner role.
     * @param role The role identifier to revoke
     * @param account The account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) public override {
        if (role == OWNER_ROLE) {
            revert OwnerRoleCannotBeRevoked();
        }
        super.revokeRole(role, account);
    }

    /**
     * @dev Overrides renounceRole to prevent renouncing the owner role.
     * @param role The role identifier to renounce
     * @param callerConfirmation The caller confirmation
     */
    function renounceRole(bytes32 role, address callerConfirmation) public override {
        if (role == OWNER_ROLE) {
            revert OwnerRoleCannotBeRevoked();
        }
        super.renounceRole(role, callerConfirmation);
    }

    /**
     * @dev Overrides _grantRole to update owner tracking.
     * Be aware that incorrect use of this function can grant owner role to multiple accounts
     * @param role The role identifier to grant
     * @param account The account to grant the role to
     * @return bool True if the role was granted
     */
    function _grantRole(bytes32 role, address account) internal override returns (bool) {
        bool granted = super._grantRole(role, account);
        if (granted && role == OWNER_ROLE) {
            OwnershipManagerStorage storage $ = _getOwnershipManagerStorage();
            $.owner = account;
        }
        return granted;
    }

    /**
     * @dev Overrides _revokeRole to update owner tracking.
     * Be aware that incorrect use of this function can revoke owner role from multiple accounts, potentially leading to a situation where there is no owner.
     * @param role The role identifier to revoke
     * @param account The account to revoke the role from
     * @return bool True if the role was revoked
     */
    function _revokeRole(bytes32 role, address account) internal override returns (bool) {
        bool revoked = super._revokeRole(role, account);
        if (revoked && role == OWNER_ROLE) {
            OwnershipManagerStorage storage $ = _getOwnershipManagerStorage();
            $.owner = address(0);
        }
        return revoked;
    }
} 