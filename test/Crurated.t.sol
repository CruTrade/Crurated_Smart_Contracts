// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { Crurated } from "../src/Crurated.sol";
import { CruratedBase } from "../src/abstracts/CruratedBase.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title CruratedTest
 * @notice Test suite for the Crurated contract
 * @dev Tests core functionality including initialization, minting, migration, status updates,
 *      metadata management, transfer restrictions, and pausing
 */
contract CruratedTest is Test {
    using Strings for uint256;

    // Contract instances
    Crurated implementation;
    Crurated proxy;
    ERC1967Proxy proxyContract;

    // Test addresses
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);
    address admin = address(0x4);

    // Test constants
    string constant TEST_CID = "QmTest1234567890";

    // Status IDs for testing
    uint256 createdStatusId;
    uint256 certifiedStatusId;
    uint256 processedStatusId;
    uint256 shippedStatusId;

    // Events to test against
    event MetadataUpdated(uint256 indexed tokenId, string cid);
    event ProvenanceUpdated(
        uint256 indexed tokenId,
        uint256 indexed statusId,
        uint256 timestamp,
        string reason
    );
    event ProvenanceTypeAdded(uint256 indexed statusId, string name);
    event Paused(address account);
    event Unpaused(address account);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    /**
     * @notice Setup function called before each test
     * @dev Deploys the implementation contract and sets up the UUPS proxy pattern
     */
    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation contract with initial owner and admin
        implementation = new Crurated(owner, admin);

        // Deploy proxy contract pointing to the implementation
        bytes memory initData = abi.encodeWithSelector(
            Crurated.initialize.selector,
            owner,
            admin
        );
        proxyContract = new ERC1967Proxy(address(implementation), initData);

        // Create a reference to the proxy with the Crurated ABI
        proxy = Crurated(address(proxyContract));

        vm.stopPrank();
        // Register status types for testing (admin only)
        vm.startPrank(admin);
        createdStatusId = proxy.addStatus("Created");
        certifiedStatusId = proxy.addStatus("Certified");
        processedStatusId = proxy.addStatus("Processed");
        shippedStatusId = proxy.addStatus("Shipped");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testInitialization() public view {
        assertEq(proxy.name(), "Crurated");
        assertEq(proxy.symbol(), "CRURATED");
        assertEq(proxy.owner(), owner);
        assertEq(proxy.admin(), admin);
    }

    function testCannotInitializeAgain() public {
        vm.startPrank(owner);
        vm.expectRevert();
        proxy.initialize(owner, admin);
        vm.stopPrank();
    }

    function testCannotInitializeImplementation() public {
        vm.startPrank(owner);
        vm.expectRevert();
        implementation.initialize(owner, admin);
        vm.stopPrank();
    }

    function testConstructorValidatesAdmin() public {
        // Test that constructor rejects zero address for admin
        vm.expectRevert("Admin cannot be zero address");
        new Crurated(owner, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        STATUS MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testAddStatus() public {
        vm.startPrank(admin);

        vm.expectEmit(true, true, true, true);
        emit ProvenanceTypeAdded(5, "New Status");

        uint256 statusId = proxy.addStatus("New Status");
        assertEq(statusId, 5);
        assertEq(proxy.statusName(statusId), "New Status");

        vm.stopPrank();
    }

    function testStatusIdSequence() public {
        vm.startPrank(admin);

        assertEq(proxy.nextStatusId(), 5); // After setUp, next should be 5

        uint256 newStatusId = proxy.addStatus("Test Status");
        assertEq(newStatusId, 5);
        assertEq(proxy.nextStatusId(), 6);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function testMintSingleToken() public {
        vm.startPrank(admin);
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);

        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], 1);
        assertEq(proxy.balanceOf(owner, 1), 1);
        assertEq(proxy.cidOf(1), TEST_CID);
        // Check URI
        assertEq(proxy.uri(1), string(abi.encodePacked("ipfs://", TEST_CID)));
        vm.stopPrank();
    }

    function testMintMultipleTokens() public {
        vm.startPrank(admin);
        string[] memory cids = new string[](3);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";
        cids[2] = "QmTest3";

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 5;
        amounts[2] = 10;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);

        assertEq(tokenIds.length, 3);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(tokenIds[2], 3);

        // Check balances
        assertEq(proxy.balanceOf(owner, 1), 1);
        assertEq(proxy.balanceOf(owner, 2), 5);
        assertEq(proxy.balanceOf(owner, 3), 10);

        // Check CIDs
        assertEq(proxy.cidOf(1), "QmTest1");
        assertEq(proxy.cidOf(2), "QmTest2");
        assertEq(proxy.cidOf(3), "QmTest3");

        vm.stopPrank();
    }

    function testCannotMintWithZeroAmount() public {
        vm.startPrank(admin);

        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0; // Zero amount, should revert

        vm.expectRevert(abi.encodeWithSignature("ZeroMintAmount()"));
        proxy.mint(cids, amounts);

        vm.stopPrank();
    }

    function testCannotMintWithMismatchedArrays() public {
        vm.startPrank(admin);

        string[] memory cids = new string[](2);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";

        uint256[] memory amounts = new uint256[](1); // Only one amount
        amounts[0] = 1;

        vm.expectRevert(abi.encodeWithSignature("InvalidBatchInput()"));
        proxy.mint(cids, amounts);

        vm.stopPrank();
    }

    function testCannotMintFromNonAdmin() public {
        vm.startPrank(user1);

        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(bytes("Caller is not admin"));
        proxy.mint(cids, amounts);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            MIGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testMigration() public {
        vm.startPrank(admin);

        // Prepare migration data
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;

        // Prepare status history
        CruratedBase.Status[][] memory statusHistory = new CruratedBase.Status[][](1);
        statusHistory[0] = new CruratedBase.Status[](2);

        statusHistory[0][0] = CruratedBase.Status({
            statusId: createdStatusId,
            timestamp: 1000000,
            reason: "Initial creation"
        });

        statusHistory[0][1] = CruratedBase.Status({
            statusId: certifiedStatusId,
            timestamp: 1100000,
            reason: "Quality certified"
        });

        // Migrate the token
        uint256[] memory tokenIds = proxy.migrate(cids, amounts, statusHistory);

        // Check the result
        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], 1);
        assertEq(proxy.balanceOf(owner, 1), 5);
        assertEq(proxy.cidOf(1), TEST_CID);

        vm.stopPrank();
    }

    function testMigrateMultipleTokens() public {
        vm.startPrank(admin);

        // Prepare migration data for multiple tokens
        string[] memory cids = new string[](2);
        cids[0] = "QmToken1";
        cids[1] = "QmToken2";

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 10;

        // Prepare status history
        CruratedBase.Status[][] memory statusHistory = new CruratedBase.Status[][](2);

        // First token history
        statusHistory[0] = new CruratedBase.Status[](2);
        statusHistory[0][0] = CruratedBase.Status({
            statusId: createdStatusId,
            timestamp: 1000000,
            reason: "Token 1 created"
        });
        statusHistory[0][1] = CruratedBase.Status({
            statusId: certifiedStatusId,
            timestamp: 1100000,
            reason: "Token 1 certified"
        });

        // Second token history
        statusHistory[1] = new CruratedBase.Status[](3);
        statusHistory[1][0] = CruratedBase.Status({
            statusId: createdStatusId,
            timestamp: 1200000,
            reason: "Token 2 created"
        });
        statusHistory[1][1] = CruratedBase.Status({
            statusId: processedStatusId,
            timestamp: 1300000,
            reason: "Token 2 processed"
        });
        statusHistory[1][2] = CruratedBase.Status({
            statusId: shippedStatusId,
            timestamp: 1400000,
            reason: "Token 2 shipped"
        });

        // Migrate the tokens
        uint256[] memory tokenIds = proxy.migrate(cids, amounts, statusHistory);

        // Check the results
        assertEq(tokenIds.length, 2);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);

        // Check first token
        assertEq(proxy.balanceOf(owner, 1), 1);
        assertEq(proxy.cidOf(1), "QmToken1");

        // Check second token
        assertEq(proxy.balanceOf(owner, 2), 10);
        assertEq(proxy.cidOf(2), "QmToken2");

        vm.stopPrank();
    }

    function testCannotMigrateWithZeroAmount() public {
        vm.startPrank(admin);

        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0; // Zero amount, should revert

        CruratedBase.Status[][] memory statusHistory = new CruratedBase.Status[][](1);
        statusHistory[0] = new CruratedBase.Status[](1);
        statusHistory[0][0] = CruratedBase.Status({
            statusId: createdStatusId,
            timestamp: 1000000,
            reason: "Test"
        });

        vm.expectRevert(abi.encodeWithSignature("ZeroMintAmount()"));
        proxy.migrate(cids, amounts, statusHistory);

        vm.stopPrank();
    }

    function testCannotMigrateWithMismatchedArrays() public {
        vm.startPrank(admin);

        string[] memory cids = new string[](2);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";

        uint256[] memory amounts = new uint256[](1); // Only one amount
        amounts[0] = 1;

        CruratedBase.Status[][] memory statusHistory = new CruratedBase.Status[][](2);
        statusHistory[0] = new CruratedBase.Status[](0);
        statusHistory[1] = new CruratedBase.Status[](0);

        vm.expectRevert(abi.encodeWithSignature("InvalidBatchInput()"));
        proxy.migrate(cids, amounts, statusHistory);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         STATUS UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpdateSingleStatus() public {
        vm.startPrank(admin);

        // Mint a token
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        uint256 tokenId = tokenIds[0];

        // Update status
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenId;

        CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](1);
        statuses[0] = new CruratedBase.Status[](1);
        statuses[0][0] = CruratedBase.Status({
            statusId: certifiedStatusId,
            timestamp: uint256(block.timestamp),
            reason: "Certified by admin"
        });

        // Update status and check event
        vm.expectEmit(true, true, true, true);
        emit ProvenanceUpdated(tokenId, certifiedStatusId, uint256(block.timestamp), "Certified by admin");

        proxy.update(updateIds, statuses);

        vm.stopPrank();
    }

    function testUpdateMultipleStatuses() public {
        vm.startPrank(admin);

        // Mint multiple tokens
        string[] memory cids = new string[](2);
        cids[0] = "QmToken1";
        cids[1] = "QmToken2";

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);

        // Update statuses for both tokens
        uint256[] memory updateIds = new uint256[](2);
        updateIds[0] = tokenIds[0];
        updateIds[1] = tokenIds[1];

        CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](2);
        statuses[0] = new CruratedBase.Status[](1);
        statuses[0][0] = CruratedBase.Status({
            statusId: certifiedStatusId,
            timestamp: uint256(block.timestamp),
            reason: "Token 1 certified"
        });
        statuses[1] = new CruratedBase.Status[](1);
        statuses[1][0] = CruratedBase.Status({
            statusId: processedStatusId,
            timestamp: uint256(block.timestamp),
            reason: "Token 2 processed"
        });

        proxy.update(updateIds, statuses);

        vm.stopPrank();
    }

    function testCannotUpdateNonExistentToken() public {
        vm.startPrank(admin);

        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = 999; // Non-existent token

        CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](1);
        statuses[0] = new CruratedBase.Status[](1);
        statuses[0][0] = CruratedBase.Status({
            statusId: certifiedStatusId,
            timestamp: uint256(block.timestamp),
            reason: "Test"
        });

        vm.expectRevert(
            abi.encodeWithSignature("TokenNotExists(uint256)", 999)
        );
        proxy.update(updateIds, statuses);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetCIDs() public {
        vm.startPrank(admin);

        // Mint a token
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        uint256 tokenId = tokenIds[0];

        // Update CID
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenId;

        string[] memory newCids = new string[](1);
        newCids[0] = "QmNewCID";

        vm.expectEmit(true, true, true, true);
        emit MetadataUpdated(tokenId, "QmNewCID");

        proxy.setCIDs(updateIds, newCids);

        // Check updated CID
        assertEq(proxy.cidOf(tokenId), "QmNewCID");
        assertEq(
            proxy.uri(tokenId),
            string(abi.encodePacked("ipfs://", "QmNewCID"))
        );

        vm.stopPrank();
    }

    function testCannotSetCIDsForNonExistentToken() public {
        vm.startPrank(admin);

        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = 999; // Non-existent token

        string[] memory newCids = new string[](1);
        newCids[0] = "QmNewCID";

        vm.expectRevert(
            abi.encodeWithSignature("TokenNotExists(uint256)", 999)
        );
        proxy.setCIDs(updateIds, newCids);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         SOULBOUND TESTS
    //////////////////////////////////////////////////////////////*/

    function testCannotTransferToken() public {
        vm.startPrank(admin);

        // Mint a token
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        uint256 tokenId = tokenIds[0];

        // Try to transfer - should revert
        vm.expectRevert(abi.encodeWithSignature("TokenSoulbound()"));
        proxy.safeTransferFrom(owner, user1, tokenId, 1, "");

        vm.stopPrank();
    }

    function testCannotBatchTransferTokens() public {
        vm.startPrank(admin);

        // Mint multiple tokens
        string[] memory cids = new string[](2);
        cids[0] = "QmToken1";
        cids[1] = "QmToken2";

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);

        // Try batch transfer - should revert
        uint256[] memory transferIds = new uint256[](2);
        transferIds[0] = tokenIds[0];
        transferIds[1] = tokenIds[1];

        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;

        vm.expectRevert(abi.encodeWithSignature("TokenSoulbound()"));
        proxy.safeBatchTransferFrom(
            owner,
            user1,
            transferIds,
            transferAmounts,
            ""
        );

        vm.stopPrank();
    }

    function testCannotSetApprovalForAll() public {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSignature("TokenSoulbound()"));
        proxy.setApprovalForAll(user1, true);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         PAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    function testPauseAndUnpause() public {
        vm.startPrank(owner);

        // Check initial state
        assertEq(proxy.paused(), false);

        // Pause
        vm.expectEmit(true, true, true, true);
        emit Paused(owner);
        proxy.pause();

        // Check paused state
        assertEq(proxy.paused(), true);

        // Unpause
        vm.expectEmit(true, true, true, true);
        emit Unpaused(owner);
        proxy.unpause();

        // Check unpaused state
        assertEq(proxy.paused(), false);

        vm.stopPrank();
    }

    function testCannotPauseFromNonOwner() public {
        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        proxy.pause();

        vm.stopPrank();
    }

    function testCannotUnpauseFromNonOwner() public {
        vm.startPrank(owner);
        proxy.pause();
        vm.stopPrank();

        vm.startPrank(user1);

        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        proxy.unpause();

        vm.stopPrank();
    }

    function testCannotMintWhenPaused() public {
        vm.startPrank(owner);
        // Pause the contract
        proxy.pause();
        vm.stopPrank();

        vm.startPrank(admin);
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Try to mint while paused
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        proxy.mint(cids, amounts);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpgradeContract() public {
        vm.startPrank(owner);

        // Deploy new implementation
        Crurated newImplementation = new Crurated(owner, admin);

        // Upgrade to new implementation
        proxy.upgradeToAndCall(address(newImplementation), "");

        // Contract should still work after upgrade
        vm.startPrank(admin);
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], 1);

        vm.stopPrank();
    }

    function testCannotUpgradeFromNonOwner() public {
        vm.startPrank(user1);

        // Deploy new implementation
        Crurated newImplementation = new Crurated(owner, admin);

        // Try to upgrade from non-owner
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        proxy.upgradeToAndCall(address(newImplementation), "");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        GAS OPTIMIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGasEfficiencyForBatchMint() public {
        vm.startPrank(admin);

        // Prepare large batch
        uint256 batchSize = 10;
        string[] memory cids = new string[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);

        for (uint i = 0; i < batchSize; i++) {
            cids[i] = string(abi.encodePacked("QmTest", i.toString()));
            amounts[i] = 1;
        }

        // Measure gas usage
        uint256 gasStart = gasleft();
        proxy.mint(cids, amounts);
        uint256 gasUsed = gasStart - gasleft();

        // Log gas used for analysis
        console.log("Gas used for minting %d tokens: %d", batchSize, gasUsed);

        vm.stopPrank();
    }

    function testGasEfficiencyForBatchMigrate() public {
        vm.startPrank(admin);

        // Prepare large batch
        uint256 batchSize = 5;
        string[] memory cids = new string[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);
        CruratedBase.Status[][] memory statusHistory = new CruratedBase.Status[][](batchSize);

        for (uint i = 0; i < batchSize; i++) {
            cids[i] = string(abi.encodePacked("QmMigrate", i.toString()));
            amounts[i] = 1;

            statusHistory[i] = new CruratedBase.Status[](2);
            statusHistory[i][0] = CruratedBase.Status({
                statusId: createdStatusId,
                timestamp: uint256(1000000 + i * 1000),
                reason: "Migrated creation"
            });
            statusHistory[i][1] = CruratedBase.Status({
                statusId: certifiedStatusId,
                timestamp: uint256(1100000 + i * 1000),
                reason: "Migrated certification"
            });
        }

        // Measure gas usage
        uint256 gasStart = gasleft();
        proxy.migrate(cids, amounts, statusHistory);
        uint256 gasUsed = gasStart - gasleft();

        // Log gas used for analysis
        console.log("Gas used for migrating %d tokens: %d", batchSize, gasUsed);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN/OWNER ROLE TESTS
    //////////////////////////////////////////////////////////////*/

    // --- ADMIN-ONLY FUNCTION TESTS ---

    // Only admin can mint
    function testOnlyAdminCanMint() public {
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // Non-admin (user1) cannot mint
        vm.startPrank(user1);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.mint(cids, amounts);
        vm.stopPrank();

        // Owner cannot mint
        vm.startPrank(owner);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.mint(cids, amounts);
        vm.stopPrank();

        // Admin can mint
        vm.startPrank(admin);
        proxy.mint(cids, amounts);
        vm.stopPrank();
    }

    // Only admin can migrate
    function testOnlyAdminCanMigrate() public {
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](1);
        statuses[0] = new CruratedBase.Status[](0);

        // Non-admin (user1) cannot migrate
        vm.startPrank(user1);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.migrate(cids, amounts, statuses);
        vm.stopPrank();

        // Owner cannot migrate
        vm.startPrank(owner);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.migrate(cids, amounts, statuses);
        vm.stopPrank();

        // Admin can migrate
        vm.startPrank(admin);
        proxy.migrate(cids, amounts, statuses);
        vm.stopPrank();
    }

    // Only admin can update
    function testOnlyAdminCanUpdate() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](1);
        statuses[0] = new CruratedBase.Status[](0);

        // Non-admin (user1) cannot update
        vm.startPrank(user1);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.update(tokenIds, statuses);
        vm.stopPrank();

        // Owner cannot update
        vm.startPrank(owner);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.update(tokenIds, statuses);
        vm.stopPrank();

        // Admin can update
        vm.startPrank(admin);
        proxy.update(tokenIds, statuses);
        vm.stopPrank();
    }

    // Only admin can setCIDs
    function testOnlyAdminCanSetCIDs() public {
        // First mint a token as admin
        vm.startPrank(admin);
        string[] memory mintCids = new string[](1);
        mintCids[0] = TEST_CID;
        uint256[] memory mintAmounts = new uint256[](1);
        mintAmounts[0] = 1;
        uint256[] memory tokenIds = proxy.mint(mintCids, mintAmounts);
        vm.stopPrank();

        uint256[] memory updateTokenIds = new uint256[](1);
        updateTokenIds[0] = tokenIds[0];
        string[] memory cids = new string[](1);
        cids[0] = "QmNewCID";

        // Non-admin (user1) cannot setCIDs
        vm.startPrank(user1);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.setCIDs(updateTokenIds, cids);
        vm.stopPrank();

        // Owner cannot setCIDs
        vm.startPrank(owner);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.setCIDs(updateTokenIds, cids);
        vm.stopPrank();

        // Admin can setCIDs
        vm.startPrank(admin);
        proxy.setCIDs(updateTokenIds, cids);
        vm.stopPrank();
    }

    // --- OWNER-ONLY FUNCTION TESTS ---

    // Only owner can set admin
    function testOnlyOwnerCanSetAdmin() public {
        // Non-owner (user1) cannot set admin
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.setAdmin(user2);
        vm.stopPrank();

        // Admin cannot set admin
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        proxy.setAdmin(user2);
        vm.stopPrank();

        // Owner can set admin
        vm.startPrank(owner);
        proxy.setAdmin(user2);
        assertEq(proxy.admin(), user2);
        vm.stopPrank();
    }

    // Only owner can pause/unpause
    function testOnlyOwnerCanPauseUnpause() public {
        // Non-owner (user1) cannot pause
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.pause();
        vm.stopPrank();

        // Admin cannot pause
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        proxy.pause();
        vm.stopPrank();

        // Owner can pause
        vm.startPrank(owner);
        proxy.pause();
        proxy.unpause();
        vm.stopPrank();
    }

    // Only owner can add status
    function testOnlyAdminCanAddStatus() public {
        // Non-admin (user1) cannot add status
        vm.startPrank(user1);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.addStatus("ShouldFail");
        vm.stopPrank();

        // Owner cannot add status
        vm.startPrank(owner);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.addStatus("ShouldFail");
        vm.stopPrank();

        // Admin can add status
        vm.startPrank(admin);
        uint256 statusId = proxy.addStatus("NewStatus");
        assertEq(proxy.statusName(statusId), "NewStatus");
        vm.stopPrank();
    }

    function testAdminSetAndEvent() public {
        vm.startPrank(owner);
        address newAdmin = address(0x5);
        vm.expectEmit(true, true, false, true);
        emit AdminChanged(admin, newAdmin);
        proxy.setAdmin(newAdmin);
        assertEq(proxy.admin(), newAdmin);
        vm.stopPrank();
    }

    function testAdminCannotBeZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert(bytes("Admin cannot be zero address"));
        proxy.setAdmin(address(0));
        vm.stopPrank();
    }

    function testOwnerCannotCallAdminFunctions() public {
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        vm.startPrank(owner);
        vm.expectRevert(bytes("Caller is not admin"));
        proxy.mint(cids, amounts);
        vm.stopPrank();
    }

    function testAdminCannotCallOwnerFunctions() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        proxy.setAdmin(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        proxy.pause();
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        proxy.unpause();

        vm.stopPrank();
    }

    function testMintToOwnerAddress() public {
        vm.startPrank(admin);
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        assertEq(proxy.balanceOf(owner, tokenIds[0]), 1);
        vm.stopPrank();
    }

    function testMigrateToOwnerAddress() public {
        vm.startPrank(admin);
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        CruratedBase.Status[][] memory statuses = new CruratedBase.Status[][](1);
        statuses[0] = new CruratedBase.Status[](0);
        uint256[] memory tokenIds = proxy.migrate(cids, amounts, statuses);
        assertEq(proxy.balanceOf(owner, tokenIds[0]), 1);
        vm.stopPrank();
    }
}