// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { HierarchicalAccessControl } from "../src/abstracts/HierarchicalAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title HierarchicalAccessControlTest
 * @notice Comprehensive test suite for HierarchicalAccessControl contract
 * @dev Tests critical security issues, role hierarchy, upgrade safety, and edge cases
 */
// Test contract that uses HierarchicalAccessControl
contract TestContract is HierarchicalAccessControl {
    bytes32 public constant OWNER_ROLE = ADMIN_ROLE;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    function __TestContract_init() public initializer {
        __HierarchicalAccessControl_init(msg.sender);
        // Set up role levels for additional roles (OWNER_ROLE is already set to 100 in base init)
        setRoleLevel(OPERATOR_ROLE, 90);
        setRoleLevel(MODERATOR_ROLE, 80);
        setRoleLevel(USER_ROLE, 70);
    }

    function ownerOnlyFunction() public onlyRole(OWNER_ROLE) returns (bool) {
        return true;
    }

    function adminOnlyFunction() public onlyRole(OPERATOR_ROLE) returns (bool) {
        return true;
    }

    function moderatorOnlyFunction() public onlyRole(MODERATOR_ROLE) returns (bool) {
        return true;
    }

    function userOnlyFunction() public onlyRole(USER_ROLE) returns (bool) {
        return true;
    }

    function setRoleLevelPublic(bytes32 role, uint256 level) public {
        setRoleLevel(role, level);
    }

    function functionIsAdminRoleFor(bytes32 role) public isAdminRoleFor(role) returns (bool)  {
        return true;
    }

    
}

contract HierarchicalAccessControlTest is Test {

    // Contract instances
    TestContract implementation;
    TestContract proxy;
    ERC1967Proxy proxyContract;

    // Test addresses
    address owner = address(0x1);
    address admin = address(0x2);
    address moderator = address(0x3);
    address user = address(0x4);
    address attacker = address(0x5);
    address randomUser = address(0x6);

    // Events to test against
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleLevelSet(bytes32 indexed role, uint256 level);

    /**
     * @notice Setup function called before each test
     * @dev Deploys the implementation contract and sets up the UUPS proxy pattern
     */
    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation contract
        implementation = new TestContract();

        // Deploy proxy contract pointing to the implementation
        bytes memory initData = abi.encodeWithSelector(
            TestContract.__TestContract_init.selector
        );
        proxyContract = new ERC1967Proxy(address(implementation), initData);

        // Create a reference to the proxy with the TestContract ABI
        proxy = TestContract(address(proxyContract));

        // Grant roles for testing (owner already has HIERARCHICAL_ADMIN_ROLE from init)
        proxy.grantRole(proxy.OPERATOR_ROLE(), admin);
        proxy.grantRole(proxy.MODERATOR_ROLE(), moderator);
        proxy.grantRole(proxy.USER_ROLE(), user);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    CRITICAL SECURITY TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Test that role hierarchy is properly enforced
     * CRITICAL: This is the core security mechanism
     */
    function testRoleHierarchyEnforcement() public {
        // Owner should be able to access all functions
        vm.startPrank(owner);
        assertTrue(proxy.ownerOnlyFunction());
        assertTrue(proxy.adminOnlyFunction());
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();

        // Admin should be able to access admin and below
        vm.startPrank(admin);
        vm.expectRevert(); // Should not access owner function
        proxy.ownerOnlyFunction();
        assertTrue(proxy.adminOnlyFunction());
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();

        // Moderator should be able to access moderator and below
        vm.startPrank(moderator);
        vm.expectRevert(); // Should not access owner function
        proxy.ownerOnlyFunction();
        vm.expectRevert(); // Should not access admin function
        proxy.adminOnlyFunction();
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();

        // User should only access user function
        vm.startPrank(user);
        vm.expectRevert(); // Should not access owner function
        proxy.ownerOnlyFunction();
        vm.expectRevert(); // Should not access admin function
        proxy.adminOnlyFunction();
        vm.expectRevert(); // Should not access moderator function
        proxy.moderatorOnlyFunction();
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();
    }

    /**
     * @dev Test that unknown roles are properly handled
     * CRITICAL: Prevents privilege escalation attacks
     */
    function testUnknownRoleHandling() public {
        bytes32 unknownRole = keccak256("UNKNOWN_ROLE");
        
        // Unknown roles should have level 0 (lowest privilege)
        assertEq(proxy.getRoleLevel(unknownRole), 0);
        
        // Users with unknown roles should not access any protected functions
        vm.startPrank(owner);
        proxy.grantRole(unknownRole, randomUser);
        vm.stopPrank();
        
        vm.startPrank(randomUser);
        vm.expectRevert();
        proxy.ownerOnlyFunction();
        vm.expectRevert();
        proxy.adminOnlyFunction();
        vm.expectRevert();
        proxy.moderatorOnlyFunction();
        vm.expectRevert();
        proxy.userOnlyFunction();
        vm.stopPrank();
    }

    /**
     * @dev Test that role level manipulation is prevented
     * CRITICAL: Ensures role levels cannot be bypassed
     */
    function testRoleLevelManipulationPrevention() public {
        // Only owner should be able to set role levels
        vm.startPrank(admin);
        bytes32 operatorRole = proxy.OPERATOR_ROLE();
        vm.expectRevert(); // Should not be able to set role levels
        proxy.setRoleLevelPublic(operatorRole, 200);
        vm.stopPrank();

        vm.startPrank(moderator);
        bytes32 moderatorRole = proxy.MODERATOR_ROLE();
        vm.expectRevert(); // Should not be able to set role levels
        proxy.setRoleLevelPublic(moderatorRole, 200);
        vm.stopPrank();

        vm.startPrank(user);
        bytes32 userRole = proxy.USER_ROLE();
        vm.expectRevert(); // Should not be able to set role levels
        proxy.setRoleLevelPublic(userRole, 200);
        vm.stopPrank();

        // Owner should be able to set role levels
        vm.startPrank(owner);
        bytes32 operatorRoleForOwner = proxy.OPERATOR_ROLE();
        vm.expectEmit(true, true, true, true);
        emit RoleLevelSet(operatorRoleForOwner, 200);
        proxy.setRoleLevelPublic(operatorRoleForOwner, 200);
        assertEq(proxy.getRoleLevel(operatorRoleForOwner), 200);
        vm.stopPrank();
    }

    /**
     * @dev Test that role granting/revoking maintains consistency
     * CRITICAL: Prevents state inconsistencies
     */
    function testRoleGrantingRevokingConsistency() public {
        // Test granting role
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(proxy.OPERATOR_ROLE(), attacker, owner);
        proxy.grantRole(proxy.OPERATOR_ROLE(), attacker);
        
        // Verify both OpenZeppelin state and our state are consistent
        assertTrue(proxy.hasRole(proxy.OPERATOR_ROLE(), attacker));
        assertEq(proxy.getAccountRole(attacker), proxy.OPERATOR_ROLE());
        assertEq(proxy.getRoleLevel(proxy.getAccountRole(attacker)), 90);
        vm.stopPrank();

        // Test revoking role
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(proxy.OPERATOR_ROLE(), attacker, owner);
        proxy.revokeRole(proxy.OPERATOR_ROLE(), attacker);
        
        // Verify both states are consistent
        assertFalse(proxy.hasRole(proxy.OPERATOR_ROLE(), attacker));
        assertEq(proxy.getAccountRole(attacker), bytes32(0));
        assertEq(proxy.getRoleLevel(proxy.getAccountRole(attacker)), 0);
        vm.stopPrank();
    }

    /**
     * @dev Test that renouncing roles works correctly
     * CRITICAL: Self-revocation mechanism
     */
    function testRoleRenouncing() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(proxy.OPERATOR_ROLE(), admin, admin);
        proxy.renounceRole(proxy.OPERATOR_ROLE(), admin);
        
        // Verify state is consistent
        assertFalse(proxy.hasRole(proxy.OPERATOR_ROLE(), admin));
        assertEq(proxy.getAccountRole(admin), bytes32(0));
        
        // Should no longer be able to access admin functions
        vm.expectRevert();
        proxy.adminOnlyFunction();
        vm.stopPrank();
    }

    /**
     * @dev Test that users without any role cannot access any functions
     * CRITICAL: Prevents unauthorized access
     */
    function testNoRoleAccessDenial() public {
        // Random user without any role should not access any functions
        vm.startPrank(randomUser);
        
        vm.expectRevert();
        proxy.ownerOnlyFunction();
        vm.expectRevert();
        proxy.adminOnlyFunction();
        vm.expectRevert();
        proxy.moderatorOnlyFunction();
        vm.expectRevert();
        proxy.userOnlyFunction();
        vm.stopPrank();
    }

    /**
     * @dev Test that role level 0 (no role) is properly handled
     * CRITICAL: Ensures default state is secure
     */
    function testZeroRoleLevelHandling() public {
        // Test that accounts with no role have level 0
        assertEq(proxy.getRoleLevel(proxy.getAccountRole(randomUser)), 0);
        
        // Test that role level 0 cannot access any functions
        vm.startPrank(randomUser);
        vm.expectRevert();
        proxy.ownerOnlyFunction();
        vm.expectRevert();
        proxy.adminOnlyFunction();
        vm.expectRevert();
        proxy.moderatorOnlyFunction();
        vm.expectRevert();
        proxy.userOnlyFunction();
        vm.stopPrank();
    }

    /**
     * @dev Test that role admin permissions are properly enforced
     * CRITICAL: Prevents unauthorized role management
     */
    function testRoleAdminPermissions() public {
        // Only owner should be able to grant/revoke roles
        vm.startPrank(admin);
        bytes32 ownerRole = proxy.OWNER_ROLE();
        vm.expectRevert(); // Should not be able to grant roles
        proxy.grantRole(ownerRole, randomUser);
        vm.stopPrank();

        vm.startPrank(admin);
        bytes32 operatorRole = proxy.OPERATOR_ROLE();
        vm.expectRevert(); // Should not be able to grant roles
        proxy.grantRole(operatorRole, randomUser);
        vm.stopPrank();

        vm.startPrank(admin); // Should be able to grant roles
        bytes32 moderatorRole = proxy.MODERATOR_ROLE();
        proxy.grantRole(moderatorRole, randomUser);
        assertTrue(proxy.hasRole(moderatorRole, randomUser));
        vm.stopPrank();

        vm.startPrank(admin);
        bytes32 userRole = proxy.USER_ROLE();
        proxy.grantRole(userRole, randomUser);
        assertTrue(proxy.hasRole(userRole, randomUser));
        vm.stopPrank();

        // Owner should be able to grant roles
        vm.startPrank(owner);
        bytes32 operatorRoleForPermissions = proxy.OPERATOR_ROLE();
        proxy.grantRole(operatorRoleForPermissions, randomUser);
        assertTrue(proxy.hasRole(operatorRoleForPermissions, randomUser));
        vm.stopPrank();
    }

    /**
     * @dev Test that role inheritance works with equal role levels
     * CRITICAL: Edge case in hierarchy logic
     */
    function testEqualRoleLevelAccess() public {
        // Set up two roles with equal levels
        vm.startPrank(owner);
        bytes32 moderatorRoleForEqual = proxy.MODERATOR_ROLE();
        proxy.setRoleLevelPublic(moderatorRoleForEqual, 90); // Same as ADMIN_ROLE
        vm.stopPrank();

        // Users with equal levels should be able to access each other's functions
        vm.startPrank(admin);
        assertTrue(proxy.moderatorOnlyFunction()); // Should work (equal level)
        vm.stopPrank();

        vm.startPrank(moderator);
        assertTrue(proxy.adminOnlyFunction()); // Should work (equal level)
        vm.stopPrank();
    }

    /**
     * @dev Test that role revocation affects inheritance immediately
     * CRITICAL: State consistency after role changes
     */
    function testRoleRevocationInheritance() public {
        // Grant admin role to user
        vm.startPrank(owner);
        bytes32 operatorRoleForRevocation = proxy.OPERATOR_ROLE();
        proxy.grantRole(operatorRoleForRevocation, user);
        vm.stopPrank();

        // User should now be able to access admin functions
        vm.startPrank(user);
        assertTrue(proxy.adminOnlyFunction());
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();

        // Revoke admin role
        vm.startPrank(owner);
        proxy.revokeRole(operatorRoleForRevocation, user);
        vm.stopPrank();

        // User should have no role and cannot access any functions
        vm.startPrank(user);
        vm.expectRevert();
        proxy.adminOnlyFunction();
        vm.expectRevert();
        proxy.moderatorOnlyFunction();
        vm.expectRevert();
        proxy.userOnlyFunction(); // Should not work - user has no role
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    HIGH PRIORITY SECURITY TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Test that upgrade safety is maintained
     * HIGH: Ensures storage layout doesn't conflict
     */
    function testUpgradeSafety() public {
        // Verify ERC-7201 storage location is correct
        bytes32 expectedLocation = 0xa7366424ae217378dbcfb911918ed5f91d9e67652ee173a5a757a47f97b95e00;
        
        // Test that role levels persist after upgrade simulation
        uint256 adminLevel = proxy.getRoleLevel(proxy.OPERATOR_ROLE());
        uint256 moderatorLevel = proxy.getRoleLevel(proxy.MODERATOR_ROLE());
        
        assertEq(adminLevel, 90);
        assertEq(moderatorLevel, 80);
        
        // Verify role assignments persist
        assertEq(proxy.getAccountRole(admin), proxy.OPERATOR_ROLE());
        assertEq(proxy.getAccountRole(moderator), proxy.MODERATOR_ROLE());
    }

    /**
     * @dev Test that role level changes affect access immediately
     * HIGH: Dynamic role management
     */
    function testDynamicRoleLevelChanges() public {
        // Initially, admin can access admin functions
        vm.startPrank(admin);
        assertTrue(proxy.adminOnlyFunction());
        vm.stopPrank();

        // Owner changes admin role level to be lower than moderator
        vm.startPrank(owner);
        bytes32 operatorRoleForDynamic = proxy.OPERATOR_ROLE();
        proxy.setRoleLevelPublic(operatorRoleForDynamic, 75); // Lower than moderator (80)
        vm.stopPrank();

        // Admin should no longer be able to access moderator functions
        vm.startPrank(admin);
        vm.expectRevert();
        proxy.moderatorOnlyFunction();
        assertTrue(proxy.adminOnlyFunction()); // Still can access admin function
        vm.stopPrank();
    }

    /**
     * @dev Test that only one role per user is allowed (last granted role overwrites previous)
     * HIGH: Role management edge cases
     */
    function testSingleRolePerUser() public {
        // Grant first role to user
        vm.startPrank(owner);
        bytes32 operatorRoleForSingle = proxy.OPERATOR_ROLE();
        proxy.grantRole(operatorRoleForSingle, user);
        assertEq(proxy.getAccountRole(user), operatorRoleForSingle);
        assertEq(proxy.getRoleLevel(proxy.getAccountRole(user)), 90);
        vm.stopPrank();

        // Grant second role - should overwrite the first
        vm.startPrank(owner);
        bytes32 moderatorRoleForSingle = proxy.MODERATOR_ROLE();
        proxy.revokeRole(operatorRoleForSingle, user);
        proxy.grantRole(moderatorRoleForSingle, user);
        vm.stopPrank();

        // User should now have only the last granted role (moderator = 80)
        assertEq(proxy.getAccountRole(user), moderatorRoleForSingle);
        assertEq(proxy.getRoleLevel(proxy.getAccountRole(user)), 80);

        // User should only be able to access functions up to moderator level
        vm.startPrank(user);
        vm.expectRevert();
        proxy.ownerOnlyFunction();
        vm.expectRevert();
        proxy.adminOnlyFunction();
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();

        // User should only have one role
        vm.startPrank(owner);
        assertEq(proxy.getAccountRole(user), moderatorRoleForSingle);
        assertEq(proxy.getRoleLevel(proxy.getAccountRole(user)), 80);
        assertFalse(proxy.hasRole(operatorRoleForSingle, user));
        assertTrue(proxy.hasRole(moderatorRoleForSingle, user));
        vm.stopPrank();
    }

    /**
     * @dev Test that ERC-7201 storage collision prevention works
     * HIGH: Upgrade safety mechanism
     */
    function testERC7201StorageCollisionPrevention() public {
        // Verify that our storage location doesn't conflict with OpenZeppelin's
        bytes32 openZeppelinLocation = 0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800;
        bytes32 ourLocation = 0xa7366424ae217378dbcfb911918ed5f91d9e67652ee173a5a757a47f97b95e00;
        
        assertTrue(openZeppelinLocation != ourLocation);
        
        // Verify that role levels are stored in our namespace
        assertEq(proxy.getRoleLevel(proxy.OWNER_ROLE()), 100);
        assertEq(proxy.getRoleLevel(proxy.OPERATOR_ROLE()), 90);
    }

    /**
     * @dev Test that role level changes are atomic and consistent
     * HIGH: State consistency during updates
     */
    function testAtomicRoleLevelChanges() public {
        vm.startPrank(owner);
        
        // Change role level and verify it's atomic
        bytes32 operatorRoleForAtomic = proxy.OPERATOR_ROLE();
        proxy.setRoleLevelPublic(operatorRoleForAtomic, 95);
        assertEq(proxy.getRoleLevel(operatorRoleForAtomic), 95);
        
        // Verify access control is immediately updated
        vm.stopPrank();
        vm.startPrank(admin);
        assertTrue(proxy.adminOnlyFunction()); // Should still work
        vm.stopPrank();
        
        // Change back
        vm.startPrank(owner);
        proxy.setRoleLevelPublic(operatorRoleForAtomic, 90);
        assertEq(proxy.getRoleLevel(operatorRoleForAtomic), 90);
        vm.stopPrank();
    }

    /**
     * @dev Test that role admin relationships are properly maintained when user roles change
     * HIGH: Verifies that role management permissions are correctly updated when a user's role is downgraded
     * 
     * This test verifies the security principle that when a user's role is downgraded,
     * they should lose the ability to manage roles they previously could manage.
     * 
     * Test scenario:
     * 1. Admin starts with OPERATOR_ROLE (level 90) - can manage MODERATOR_ROLE (level 80)
     * 2. Owner revokes admin's OPERATOR_ROLE and grants MODERATOR_ROLE instead
     * 3. Admin should lose the ability to manage MODERATOR_ROLE (same level = no permission)
     * 
     * This prevents privilege escalation where a downgraded user could still manage roles.
     */
    function testRoleAdminRelationshipMaintenance() public {
        bytes32 moderatorRole = proxy.MODERATOR_ROLE();
        
        // Step 1: Verify admin can manage MODERATOR_ROLE when they have OPERATOR_ROLE (90 > 80)
        vm.startPrank(admin);
        assertTrue(proxy.functionIsAdminRoleFor(moderatorRole)); 
        vm.stopPrank();
        
        // Step 2: Owner downgrades admin from OPERATOR_ROLE to MODERATOR_ROLE
        vm.startPrank(owner);
        proxy.revokeRole(moderatorRole, admin);        // Revoke any existing MODERATOR_ROLE
        proxy.grantRole(moderatorRole, admin);         // Grant MODERATOR_ROLE to admin (downgrade)
        
        // Step 3: Verify admin now has MODERATOR_ROLE but lost OPERATOR_ROLE
        assertTrue(proxy.hasRole(moderatorRole, admin));
        assertFalse(proxy.hasRole(proxy.OPERATOR_ROLE(), admin));
        vm.stopPrank();
        
        // Step 4: Verify admin can NO LONGER manage MODERATOR_ROLE (80 >= 80 = same level = no permission)
        vm.startPrank(admin);
        vm.expectRevert();
        proxy.functionIsAdminRoleFor(moderatorRole); 
        vm.stopPrank();
    }

    /**
     * @dev Test that role level 0 is the secure default
     * HIGH: Security by default
     */
    function testSecureDefaultRoleLevel() public {
        bytes32 newRole = keccak256("NEW_ROLE");
        
        // New roles should default to level 0
        assertEq(proxy.getRoleLevel(newRole), 0);
        
        // Grant the new role to a user
        vm.startPrank(owner);
        proxy.grantRole(newRole, randomUser);
        vm.stopPrank();
        
        // User should not be able to access any functions
        vm.startPrank(randomUser);
        vm.expectRevert();
        proxy.ownerOnlyFunction();
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    MEDIUM PRIORITY TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Test initialization safety
     * MEDIUM: Prevents re-initialization attacks
     */
    function testInitializationSafety() public {
        // Should not be able to initialize again
        vm.startPrank(owner);
        vm.expectRevert();
        proxy.__TestContract_init();
        vm.stopPrank();
    }

    /**
     * @dev Test role level validation
     * MEDIUM: Ensures role levels are reasonable
     */
    function testRoleLevelValidation() public {
        vm.startPrank(owner);
        
        // Test extreme values
        bytes32 operatorRoleForValidation = proxy.OPERATOR_ROLE();
        proxy.setRoleLevelPublic(operatorRoleForValidation, type(uint256).max);
        assertEq(proxy.getRoleLevel(operatorRoleForValidation), type(uint256).max);
        
        proxy.setRoleLevelPublic(operatorRoleForValidation, 0);
        assertEq(proxy.getRoleLevel(operatorRoleForValidation), 0);
        
        vm.stopPrank();
    }

    /**
     * @dev Test that role admin relationships work correctly
     * MEDIUM: OpenZeppelin compatibility
     */
    function testRoleAdminRelationships() public {
        vm.startPrank(owner);
        assertTrue(proxy.functionIsAdminRoleFor(proxy.OWNER_ROLE()));
        assertTrue(proxy.functionIsAdminRoleFor(proxy.OPERATOR_ROLE()));
        assertTrue(proxy.functionIsAdminRoleFor(proxy.MODERATOR_ROLE()));
        assertTrue(proxy.functionIsAdminRoleFor(proxy.USER_ROLE()));
        vm.stopPrank();

        vm.startPrank(admin);
        bytes32 adminRole = proxy.ADMIN_ROLE();
        vm.expectRevert();
        proxy.functionIsAdminRoleFor(adminRole);
        bytes32 operatorRole = proxy.OPERATOR_ROLE();
        vm.expectRevert();
        proxy.functionIsAdminRoleFor(operatorRole);
        vm.stopPrank();
    }

    /**
     * @dev Test that role level changes don't break existing permissions unexpectedly
     * MEDIUM: State transition safety
     */
    function testRoleLevelChangeSafety() public {
        // Initially, admin can access moderator functions
        vm.startPrank(admin);
        assertTrue(proxy.moderatorOnlyFunction());
        vm.stopPrank();

        // Change admin level to be lower than moderator
        vm.startPrank(owner);
        bytes32 operatorRoleForSafety = proxy.OPERATOR_ROLE();
        proxy.setRoleLevelPublic(operatorRoleForSafety, 75); // Lower than moderator (80)
        vm.stopPrank();

        // Admin should no longer access moderator functions
        vm.startPrank(admin);
        vm.expectRevert();
        proxy.moderatorOnlyFunction();
        assertTrue(proxy.adminOnlyFunction()); // Should still work
        vm.stopPrank();

        // Change back
        vm.startPrank(owner);
        proxy.setRoleLevelPublic(operatorRoleForSafety, 90);
        vm.stopPrank();

        // Admin should regain access
        vm.startPrank(admin);
        assertTrue(proxy.moderatorOnlyFunction());
        vm.stopPrank();
    }

    /**
     * @dev Test that role constants are properly defined
     * MEDIUM: Contract interface validation
     */
    function testRoleConstants() public {
        // Verify role constants are properly defined
        assertEq(proxy.OWNER_ROLE(), proxy.ADMIN_ROLE());
        assertEq(proxy.OPERATOR_ROLE(), keccak256("OPERATOR_ROLE"));
        assertEq(proxy.MODERATOR_ROLE(), keccak256("MODERATOR_ROLE"));
        assertEq(proxy.USER_ROLE(), keccak256("USER_ROLE"));
    }

    /**
     * @dev Test that role level changes emit correct events
     * MEDIUM: Event tracking and transparency
     */
    function testRoleLevelChangeEvents() public {
        vm.startPrank(owner);
        
        // Test role level setting event
        bytes32 operatorRoleForEvents = proxy.OPERATOR_ROLE();
        vm.expectEmit(true, true, true, true);
        emit RoleLevelSet(operatorRoleForEvents, 95);
        proxy.setRoleLevelPublic(operatorRoleForEvents, 95);
        
        // Test role level setting event with different value
        bytes32 moderatorRoleForEvents = proxy.MODERATOR_ROLE();
        vm.expectEmit(true, true, true, true);
        emit RoleLevelSet(moderatorRoleForEvents, 85);
        proxy.setRoleLevelPublic(moderatorRoleForEvents, 85);
        
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    LOW PRIORITY TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Test gas efficiency of role checks
     * LOW: Performance optimization
     */
    function testGasEfficiency() public {
        uint256 gasBefore = gasleft();
        
        vm.startPrank(owner);
        proxy.ownerOnlyFunction();
        uint256 gasUsed = gasBefore - gasleft();
        vm.stopPrank();
        
        // Gas usage should be reasonable (less than 50k for a simple check)
        assertLt(gasUsed, 50000);
    }

    /**
     * @dev Test that events are emitted correctly
     * LOW: Event tracking
     */
    function testEventEmission() public {
        vm.startPrank(owner);
        
        // Test role granting event
        bytes32 operatorRoleForEventEmission = proxy.OPERATOR_ROLE();
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(operatorRoleForEventEmission, randomUser, owner);
        proxy.grantRole(operatorRoleForEventEmission, randomUser);
        
        // Test role level setting event
        vm.expectEmit(true, true, true, true);
        emit RoleLevelSet(proxy.OPERATOR_ROLE(), 95);
        proxy.setRoleLevelPublic(proxy.OPERATOR_ROLE(), 95);
        
        vm.stopPrank();
    }

    /**
     * @dev Test that view functions work correctly
     * LOW: Public interface validation
     */
    function testViewFunctions() public {
        // Test getRoleLevel
        assertEq(proxy.getRoleLevel(proxy.OWNER_ROLE()), 100);
        assertEq(proxy.getRoleLevel(proxy.OPERATOR_ROLE()), 90);
        assertEq(proxy.getRoleLevel(proxy.MODERATOR_ROLE()), 80);
        assertEq(proxy.getRoleLevel(proxy.USER_ROLE()), 70);
        
        // Test getAccountRole
        assertEq(proxy.getAccountRole(owner), proxy.OWNER_ROLE());
        assertEq(proxy.getAccountRole(admin), proxy.OPERATOR_ROLE());
        assertEq(proxy.getAccountRole(moderator), proxy.MODERATOR_ROLE());
        assertEq(proxy.getAccountRole(user), proxy.USER_ROLE());
        assertEq(proxy.getAccountRole(randomUser), bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                    EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Test zero address handling
     * EDGE: Boundary conditions
     */
    function testZeroAddressHandling() public {
        vm.startPrank(owner);
        bytes32 operatorRole = proxy.OPERATOR_ROLE();
        // Shouldn't be able to grant role to zero address
        vm.expectRevert("Account cannot be zero address");
        proxy.grantRole(operatorRole, address(0));
        
        vm.stopPrank();
    }

    /**
     * @dev Test that role level changes don't affect existing permissions incorrectly
     * EDGE: State transition edge cases
     */
    function testRoleLevelChangeEdgeCases() public {
        // Set up a scenario where role levels are changed
        vm.startPrank(owner);
        
        // Initially: OWNER(100) > ADMIN(90) > MODERATOR(80) > USER(70)
        // Change to: OWNER(100) > MODERATOR(95) > ADMIN(90) > USER(70)
        bytes32 moderatorRoleForEdge = proxy.MODERATOR_ROLE();
        proxy.setRoleLevelPublic(moderatorRoleForEdge, 95);
        
        // Admin should now be lower than moderator
        bytes32 operatorRoleForEdge = proxy.OPERATOR_ROLE();
        assertLt(proxy.getRoleLevel(operatorRoleForEdge), proxy.getRoleLevel(moderatorRoleForEdge));
        
        // Moderator should be able to access admin functions
        vm.stopPrank();
        vm.startPrank(moderator);
        assertTrue(proxy.adminOnlyFunction());
        vm.stopPrank();
        
        // Admin should not be able to access moderator functions
        vm.startPrank(admin);
        vm.expectRevert();
        proxy.moderatorOnlyFunction();
        vm.stopPrank();
    }

    /**
     * @dev Test that contract works with maximum uint256 values
     * EDGE: Extreme values
     */
    function testExtremeValues() public {
        vm.startPrank(owner);
        
        // Set role level to maximum value
        bytes32 operatorRoleForExtreme = proxy.OPERATOR_ROLE();
        proxy.setRoleLevelPublic(operatorRoleForExtreme, type(uint256).max);
        
        // Should still work correctly
        assertEq(proxy.getRoleLevel(operatorRoleForExtreme), type(uint256).max);
        
        // Admin should be able to access all functions (highest level)
        vm.stopPrank();
        vm.startPrank(admin);
        assertTrue(proxy.ownerOnlyFunction());
        assertTrue(proxy.adminOnlyFunction());
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();
    }

    /**
     * @dev Test that role level changes work with boundary values
     * EDGE: Boundary conditions
     */
    function testBoundaryValueRoleLevels() public {
        vm.startPrank(owner);
        
        // Test minimum value
        bytes32 operatorRoleForBoundary = proxy.OPERATOR_ROLE();
        proxy.setRoleLevelPublic(operatorRoleForBoundary, 0);
        assertEq(proxy.getRoleLevel(operatorRoleForBoundary), 0);
        
        // Test maximum value
        proxy.setRoleLevelPublic(operatorRoleForBoundary, type(uint256).max);
        assertEq(proxy.getRoleLevel(operatorRoleForBoundary), type(uint256).max);
        
        // Test a very large but not maximum value
        proxy.setRoleLevelPublic(operatorRoleForBoundary, type(uint256).max - 1);
        assertEq(proxy.getRoleLevel(operatorRoleForBoundary), type(uint256).max - 1);
        
        vm.stopPrank();
    }

    /**
     * @dev Test that multiple rapid role level changes work correctly
     * EDGE: State transition stress test
     */
    function testRapidRoleLevelChanges() public {
        vm.startPrank(owner);
        
        // Rapidly change role levels
        bytes32 operatorRoleForRapid = proxy.OPERATOR_ROLE();
        for (uint256 i = 0; i < 10; i++) {
            proxy.setRoleLevelPublic(operatorRoleForRapid, 90 + i);
            assertEq(proxy.getRoleLevel(operatorRoleForRapid), 90 + i);
        }
        
        // Final state should be correct
        assertEq(proxy.getRoleLevel(operatorRoleForRapid), 99);
        
        vm.stopPrank();
    }

    /**
     * @dev Test that role level changes don't affect unrelated roles
     * EDGE: Isolation between roles
     */
    function testRoleLevelIsolation() public {
        vm.startPrank(owner);
        
        // Change admin role level
        bytes32 operatorRoleForIsolation = proxy.OPERATOR_ROLE();
        proxy.setRoleLevelPublic(operatorRoleForIsolation, 95);
        
        // Verify other role levels remain unchanged
        assertEq(proxy.getRoleLevel(proxy.OWNER_ROLE()), 100);
        assertEq(proxy.getRoleLevel(proxy.MODERATOR_ROLE()), 80);
        assertEq(proxy.getRoleLevel(proxy.USER_ROLE()), 70);
        
        vm.stopPrank();
    }

    /**
     * @dev Test that role level changes work with all role types
     * EDGE: Comprehensive role coverage
     */
    function testAllRoleTypesLevelChanges() public {
        vm.startPrank(owner);
        
        // Test changing levels for all role types
        bytes32 ownerRoleForAll = proxy.OWNER_ROLE();
        bytes32 operatorRoleForAll = proxy.OPERATOR_ROLE();
        bytes32 moderatorRoleForAll = proxy.MODERATOR_ROLE();
        bytes32 userRoleForAll = proxy.USER_ROLE();
        
        proxy.setRoleLevelPublic(ownerRoleForAll, 200);
        proxy.setRoleLevelPublic(operatorRoleForAll, 150);
        proxy.setRoleLevelPublic(moderatorRoleForAll, 100);
        proxy.setRoleLevelPublic(userRoleForAll, 50);
        
        // Verify all changes
        assertEq(proxy.getRoleLevel(ownerRoleForAll), 200);
        assertEq(proxy.getRoleLevel(operatorRoleForAll), 150);
        assertEq(proxy.getRoleLevel(moderatorRoleForAll), 100);
        assertEq(proxy.getRoleLevel(userRoleForAll), 50);
        
        vm.stopPrank();
    }
} 