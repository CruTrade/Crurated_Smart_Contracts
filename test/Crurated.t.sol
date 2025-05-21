// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/Crurated.sol";
import {CruratedBase} from "../src/abstracts/CruratedBase.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

/**
 * @title CruratedTest
 * @notice Test suite for the Crurated contract
 * @dev Tests core functionality including initialization, minting, migration, status updates,
 *      metadata management, transfer restrictions, and pausing
 */
contract CruratedTest is Test {
    using StringsUpgradeable for uint256;

    // Contract instances
    Crurated implementation;
    Crurated proxy;
    ERC1967Proxy proxyContract;

    // Test addresses
    address owner = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    // Test constants
    string constant TEST_CID = "QmTest1234567890";
    string constant TEST_GATEWAY = "https://example.com/metadata/";

    // Events to test against
    event MetadataUpdated(uint256 indexed tokenId, string cid);
    event StatusUpdated(
        uint256 indexed tokenId,
        string status,
        uint40 timestamp
    );
    event HttpGatewayUpdated(string newGateway);
    event BatchProcessed(uint256[] tokenIds, string operation);
    event Paused(address account);
    event Unpaused(address account);

    /**
     * @notice Setup function called before each test
     * @dev Deploys the implementation contract and sets up the UUPS proxy pattern
     */
    function setUp() public {
        vm.startPrank(owner);

        // Deploy implementation contract
        implementation = new Crurated();

        // Deploy proxy contract pointing to the implementation
        bytes memory initData = abi.encodeWithSelector(
            Crurated.initialize.selector,
            owner
        );
        proxyContract = new ERC1967Proxy(address(implementation), initData);

        // Create a reference to the proxy with the Crurated ABI
        proxy = Crurated(address(proxyContract));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testInitialization() public {
        assertEq(proxy.name(), "Crurated");
        assertEq(proxy.symbol(), "CRURATED");
        assertEq(proxy.owner(), owner);
    }

    function testCannotInitializeAgain() public {
        vm.startPrank(owner);
        vm.expectRevert();
        proxy.initialize(owner);
        vm.stopPrank();
    }

    function testCannotInitializeImplementation() public {
        vm.startPrank(owner);
        vm.expectRevert();
        implementation.initialize(owner);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                             MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function testMintSingleToken() public {
        vm.startPrank(owner);

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
        vm.startPrank(owner);

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
        vm.startPrank(owner);

        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0; // Zero amount, should revert

        vm.expectRevert(abi.encodeWithSignature("ZeroMintAmount()"));
        proxy.mint(cids, amounts);

        vm.stopPrank();
    }

    function testCannotMintWithMismatchedArrays() public {
        vm.startPrank(owner);

        string[] memory cids = new string[](2);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";

        uint256[] memory amounts = new uint256[](1); // Only one amount
        amounts[0] = 1;

        vm.expectRevert(abi.encodeWithSignature("InvalidBatchInput()"));
        proxy.mint(cids, amounts);

        vm.stopPrank();
    }

    function testCannotMintFromNonOwner() public {
        vm.startPrank(user1);

        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        proxy.mint(cids, amounts);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            MIGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testMigration() public {
        vm.startPrank(owner);

        // Create a single token migration data
        CruratedBase.Data[] memory migrateData = new CruratedBase.Data[](1);

        // Prepare status history
        string[] memory statuses = new string[](2);
        statuses[0] = "Created";
        statuses[1] = "Certified";

        uint40[] memory timestamps = new uint40[](2);
        timestamps[0] = 1000000;
        timestamps[1] = 1100000;

        migrateData[0] = CruratedBase.Data({
            cid: TEST_CID,
            amount: 5,
            statuses: statuses,
            timestamps: timestamps
        });

        // Migrate the token
        uint256[] memory tokenIds = proxy.migrate(migrateData);

        // Check the result
        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], 1);
        assertEq(proxy.balanceOf(owner, 1), 5);
        assertEq(proxy.cidOf(1), TEST_CID);

        vm.stopPrank();
    }

    function testMigrateMultipleTokens() public {
        vm.startPrank(owner);

        // Create multiple token migration data
        CruratedBase.Data[] memory migrateData = new CruratedBase.Data[](2);

        // First token with history
        string[] memory statuses1 = new string[](2);
        statuses1[0] = "Created";
        statuses1[1] = "Certified";

        uint40[] memory timestamps1 = new uint40[](2);
        timestamps1[0] = 1000000;
        timestamps1[1] = 1100000;

        migrateData[0] = CruratedBase.Data({
            cid: "QmToken1",
            amount: 1,
            statuses: statuses1,
            timestamps: timestamps1
        });

        // Second token with different history
        string[] memory statuses2 = new string[](3);
        statuses2[0] = "Created";
        statuses2[1] = "Processed";
        statuses2[2] = "Shipped";

        uint40[] memory timestamps2 = new uint40[](3);
        timestamps2[0] = 1200000;
        timestamps2[1] = 1300000;
        timestamps2[2] = 1400000;

        migrateData[1] = CruratedBase.Data({
            cid: "QmToken2",
            amount: 10,
            statuses: statuses2,
            timestamps: timestamps2
        });

        // Migrate the tokens
        uint256[] memory tokenIds = proxy.migrate(migrateData);

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
        vm.startPrank(owner);

        // Create token data with zero amount
        CruratedBase.Data[] memory migrateData = new CruratedBase.Data[](1);

        string[] memory statuses = new string[](1);
        statuses[0] = "Created";

        uint40[] memory timestamps = new uint40[](1);
        timestamps[0] = 1000000;

        migrateData[0] = CruratedBase.Data({
            cid: TEST_CID,
            amount: 0, // Zero amount, should revert
            statuses: statuses,
            timestamps: timestamps
        });

        vm.expectRevert(abi.encodeWithSignature("ZeroMintAmount()"));
        proxy.migrate(migrateData);

        vm.stopPrank();
    }

    function testCannotMigrateWithMismatchedArrays() public {
        vm.startPrank(owner);

        // Create token data with mismatched status/timestamp arrays
        CruratedBase.Data[] memory migrateData = new CruratedBase.Data[](1);

        string[] memory statuses = new string[](2);
        statuses[0] = "Created";
        statuses[1] = "Certified";

        uint40[] memory timestamps = new uint40[](1); // Only one timestamp
        timestamps[0] = 1000000;

        migrateData[0] = CruratedBase.Data({
            cid: TEST_CID,
            amount: 1,
            statuses: statuses,
            timestamps: timestamps
        });

        vm.expectRevert(abi.encodeWithSignature("InvalidBatchInput()"));
        proxy.migrate(migrateData);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         STATUS UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpdateCurrentStatus() public {
        vm.startPrank(owner);

        // Mint a token first
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        uint256 tokenId = tokenIds[0];

        // Update the status
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenId;

        string[] memory statuses = new string[](1);
        statuses[0] = "Certified";

        // Capture the timestamp
        uint40 timestamp = uint40(block.timestamp);

        // Update status and check event
        vm.expectEmit(true, true, true, true);
        emit StatusUpdated(tokenId, "Certified", timestamp);

        proxy.updateCurrentStatus(updateIds, statuses);

        vm.stopPrank();
    }

    function testUpdateHistoricalStatus() public {
        vm.startPrank(owner);

        // Mint a token first
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        uint256 tokenId = tokenIds[0];

        // Update historical status
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenId;

        string[] memory statuses = new string[](1);
        statuses[0] = "Historical Event";

        uint40[] memory timestamps = new uint40[](1);
        timestamps[0] = 1000000; // Historical timestamp

        // Update status and check event
        vm.expectEmit(true, true, true, true);
        emit StatusUpdated(tokenId, "Historical Event", 1000000);

        proxy.updateHistoricalStatus(updateIds, statuses, timestamps);

        vm.stopPrank();
    }

    function testUpdateMultipleStatuses() public {
        vm.startPrank(owner);

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

        string[] memory statuses = new string[](2);
        statuses[0] = "Status 1";
        statuses[1] = "Status 2";

        proxy.updateCurrentStatus(updateIds, statuses);

        vm.stopPrank();
    }

    function testCannotUpdateWithEmptyStatus() public {
        vm.startPrank(owner);

        // Mint a token
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);

        // Try to update with empty status
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenIds[0];

        string[] memory statuses = new string[](1);
        statuses[0] = ""; // Empty status

        vm.expectRevert(abi.encodeWithSignature("EmptyStatus()"));
        proxy.updateCurrentStatus(updateIds, statuses);

        vm.stopPrank();
    }

    function testCannotUpdateNonExistentToken() public {
        vm.startPrank(owner);

        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = 999; // Non-existent token

        string[] memory statuses = new string[](1);
        statuses[0] = "New Status";

        vm.expectRevert(
            abi.encodeWithSignature("TokenNotExists(uint256)", 999)
        );
        proxy.updateCurrentStatus(updateIds, statuses);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetCIDs() public {
        vm.startPrank(owner);

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

    function testSetHttpGateway() public {
        vm.startPrank(owner);

        // Set HTTP gateway
        vm.expectEmit(true, true, true, true);
        emit HttpGatewayUpdated(TEST_GATEWAY);

        proxy.setHttpGateway(TEST_GATEWAY);

        // Check gateway is set
        assertEq(proxy.httpGateway(), TEST_GATEWAY);

        // Mint a token to check httpUri
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        uint256[] memory tokenIds = proxy.mint(cids, amounts);
        uint256 tokenId = tokenIds[0];

        // Check HTTP URI
        string memory expectedUri = string(
            abi.encodePacked(TEST_GATEWAY, tokenId.toString(), ".json")
        );
        assertEq(proxy.httpUri(tokenId), expectedUri);

        vm.stopPrank();
    }

    function testCannotSetCIDsForNonExistentToken() public {
        vm.startPrank(owner);

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
        vm.startPrank(owner);

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
        vm.startPrank(owner);

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

    /*//////////////////////////////////////////////////////////////
                        CONTRACT UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpgradeContract() public {
        vm.startPrank(owner);

        // Deploy new implementation
        Crurated newImplementation = new Crurated();

        // Upgrade to new implementation
        proxy.upgradeToAndCall(address(newImplementation), "");

        // Contract should still work after upgrade
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
        Crurated newImplementation = new Crurated();

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
        vm.startPrank(owner);

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
        vm.startPrank(owner);

        // Prepare large batch
        uint256 batchSize = 5;
        CruratedBase.Data[] memory migrateData = new CruratedBase.Data[](
            batchSize
        );

        for (uint i = 0; i < batchSize; i++) {
            string[] memory statuses = new string[](2);
            statuses[0] = "Created";
            statuses[1] = "Certified";

            uint40[] memory timestamps = new uint40[](2);
            timestamps[0] = uint40(1000000 + i * 1000);
            timestamps[1] = uint40(1100000 + i * 1000);

            migrateData[i] = CruratedBase.Data({
                cid: string(abi.encodePacked("QmMigrate", i.toString())),
                amount: 1,
                statuses: statuses,
                timestamps: timestamps
            });
        }

        // Measure gas usage
        uint256 gasStart = gasleft();
        proxy.migrate(migrateData);
        uint256 gasUsed = gasStart - gasleft();

        // Log gas used for analysis
        console.log("Gas used for migrating %d tokens: %d", batchSize, gasUsed);

        vm.stopPrank();
    }
}
