// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { OwnershipManager } from "../src/abstracts/OwnershipManager.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title OwnershipManagerTest
 * @notice Test suite for OwnershipManager contract
 * @dev Tests ownership management with hierarchical access control
 */
contract TestContract is OwnershipManager {
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    function __TestContract_init(address _owner) public initializer {
        __OwnershipManager_init(_owner);
        // Set up additional role levels
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
}

contract OwnershipManagerTest is Test {
    TestContract implementation;
    TestContract proxy;
    ERC1967Proxy proxyContract;

    address owner = address(0x1);
    address newOwner = address(0x2);
    address admin = address(0x3);
    address moderator = address(0x4);
    address user = address(0x5);
    address randomUser = address(0x6);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RoleLevelSet(bytes32 indexed role, uint256 level);

    function setUp() public {
        vm.startPrank(owner);

        implementation = new TestContract();
        
        bytes memory initData = abi.encodeWithSelector(
            TestContract.__TestContract_init.selector,
            owner
        );
        proxyContract = new ERC1967Proxy(address(implementation), initData);
        proxy = TestContract(address(proxyContract));

        // Grant roles for testing
        proxy.grantRole(proxy.OPERATOR_ROLE(), admin);
        proxy.grantRole(proxy.MODERATOR_ROLE(), moderator);
        proxy.grantRole(proxy.USER_ROLE(), user);

        vm.stopPrank();
    }

    function testInitialization() public {
        assertEq(proxy.owner(), owner);
        assertTrue(proxy.isOwner(owner));
        assertTrue(proxy.hasRole(proxy.OWNER_ROLE(), owner));
        assertEq(proxy.getRoleLevel(proxy.OWNER_ROLE()), 100);
        assertEq(proxy.getRoleLevel(proxy.OPERATOR_ROLE()), 90);
    }

    function testHierarchicalAccessControl() public {
        // Owner should access all functions
        vm.startPrank(owner);
        assertTrue(proxy.ownerOnlyFunction());
        assertTrue(proxy.adminOnlyFunction());
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();

        // Admin should access admin and below
        vm.startPrank(admin);
        vm.expectRevert(); // Should not access owner function
        proxy.ownerOnlyFunction();
        assertTrue(proxy.adminOnlyFunction());
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();

        // Moderator should access moderator and below
        vm.startPrank(moderator);
        vm.expectRevert(); // Should not access owner function
        proxy.ownerOnlyFunction();
        vm.expectRevert(); // Should not access admin function
        proxy.adminOnlyFunction();
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();
    }

    function testOwnershipTransfer() public {
        vm.startPrank(owner);
        
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(owner, newOwner);
        proxy.transferOwnership(newOwner);
        
        assertEq(proxy.owner(), newOwner);
        assertTrue(proxy.isOwner(newOwner));
        assertFalse(proxy.isOwner(owner));
        vm.stopPrank();

        // New owner should have access to all functions
        vm.startPrank(newOwner);
        assertTrue(proxy.ownerOnlyFunction());
        assertTrue(proxy.adminOnlyFunction());
        assertTrue(proxy.moderatorOnlyFunction());
        assertTrue(proxy.userOnlyFunction());
        vm.stopPrank();
    }

    function testOwnerRoleProtection() public {
        vm.startPrank(owner);
        
        bytes32 ownerRole = proxy.OWNER_ROLE();
        // Should not be able to grant owner role
        vm.expectRevert(OwnershipManager.OwnerRoleCannotBeGranted.selector);
        proxy.grantRole(ownerRole, randomUser);
        
        // Should not be able to revoke owner role
        vm.expectRevert(OwnershipManager.OwnerRoleCannotBeRevoked.selector);
        proxy.revokeRole(ownerRole, owner);
        
        vm.stopPrank();

        // Owner should not be able to renounce role
        vm.startPrank(owner);
        vm.expectRevert(OwnershipManager.OwnerRoleCannotBeRevoked.selector);
        proxy.renounceRole(ownerRole, owner);
        vm.stopPrank();
    }

    function testTransferOwnershipValidation() public {
        vm.startPrank(owner);
        
        // Should not transfer to zero address
        vm.expectRevert(OwnershipManager.CannotTransferToZeroAddress.selector);
        proxy.transferOwnership(address(0));
        
        // Should not transfer to self
        vm.expectRevert(OwnershipManager.CannotTransferToSelf.selector);
        proxy.transferOwnership(owner);
        
        vm.stopPrank();

        // Non-owner should not be able to transfer ownership
        vm.startPrank(randomUser);
        vm.expectRevert(OwnershipManager.OnlyOwnerCanTransfer.selector);
        proxy.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testRoleLevelManagement() public {
        vm.startPrank(owner);
        bytes32 operatorRole = proxy.OPERATOR_ROLE();
        // Owner should be able to set role levels
        vm.expectEmit(true, true, true, true);
        emit RoleLevelSet(operatorRole, 95);
        proxy.setRoleLevel(operatorRole, 95);
        
        assertEq(proxy.getRoleLevel(operatorRole), 95);
        vm.stopPrank();

        // Non-owner should not be able to set role levels
        vm.startPrank(admin);
        vm.expectRevert();
        proxy.setRoleLevel(operatorRole, 85);
        vm.stopPrank();
    }

    function testAlwaysOneOwner() public {
        // Verify there's always exactly one owner
        assertEq(proxy.owner(), owner);
        assertTrue(proxy.isOwner(owner));
        
        // Transfer ownership
        vm.startPrank(owner);
        proxy.transferOwnership(newOwner);
        vm.stopPrank();
        
        // Verify new owner
        assertEq(proxy.owner(), newOwner);
        assertTrue(proxy.isOwner(newOwner));
        assertFalse(proxy.isOwner(owner));
        
        // Verify only one owner exists
        uint256 ownerCount = 0;
        if (proxy.isOwner(owner)) ownerCount++;
        if (proxy.isOwner(newOwner)) ownerCount++;
        if (proxy.isOwner(admin)) ownerCount++;
        if (proxy.isOwner(moderator)) ownerCount++;
        if (proxy.isOwner(user)) ownerCount++;
        if (proxy.isOwner(randomUser)) ownerCount++;
        
        assertEq(ownerCount, 1);
    }
} 