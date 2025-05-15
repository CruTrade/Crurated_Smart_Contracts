// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/Crurated.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title CruratedTest
 * @author Based on the original Crurated contract
 * @notice Comprehensive test suite for the Crurated ERC1155 contract
 * @dev Tests all major functionalities including initialization, minting, consuming,
 *      status updates, metadata management, and transfer restrictions
 */
contract CruratedTest is Test {
    // Main contract and proxy references
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
    string constant TEST_STATUS = "Produced";
    
    // Events to test against
    event TokenMinted(
        uint256 indexed tokenId,
        uint256 amount,
        bool consumable,
        bool fractionable
    );
    event TokensBatchMinted(
        uint256[] tokenIds,
        uint256[] amounts,
        bool[] consumable,
        bool[] fractionable
    );
    event StatusUpdated(
        uint256 indexed tokenId,
        string status,
        uint40 timestamp
    );
    event StatusesBatchUpdated(
        uint256[] tokenIds,
        string[] statuses,
        uint40 timestamp
    );
    event HttpGatewayUpdated(string newGateway);
    event TokenConsumed(uint256 indexed tokenId, uint256 amount);
    event TokensBatchConsumed(uint256[] tokenIds, uint256[] amounts);
    event TokenMetadataUpdated(uint256 indexed tokenId, string newCid);
    
    /**
     * @notice Setup function called before each test
     * @dev Deploys the implementation contract and sets up the UUPS proxy pattern
     */
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy implementation contract
        implementation = new Crurated();
        
        // Deploy proxy contract pointing to the implementation
        bytes memory initData = abi.encodeWithSelector(Crurated.initialize.selector, owner);
        proxyContract = new ERC1967Proxy(address(implementation), initData);
        
        // Create a reference to the proxy with the Crurated ABI
        proxy = Crurated(address(proxyContract));
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testInitialization() public {
        assertEq(proxy.NAME(), "Crurated");
        assertEq(proxy.SYMBOL(), "CRURATED");
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
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory expectedTokenIds = new uint256[](1);
        expectedTokenIds[0] = 1;
        
        bool[] memory expectedFractionable = new bool[](1);
        expectedFractionable[0] = false; // Amount is 1, so not fractionable
        
        vm.expectEmit(true, true, true, true);
        emit TokensBatchMinted(expectedTokenIds, amounts, consumable, expectedFractionable);
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], 1);
        assertEq(proxy.balanceOf(owner, 1), 1);
        assertTrue(proxy.isConsumable(1));
        assertFalse(proxy.isFractionable(1));
        assertFalse(proxy.isConsumed(1));
        
        vm.stopPrank();
    }
    
    function testMintFractionableToken() public {
        vm.startPrank(owner);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10; // More than 1 makes it fractionable
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        assertEq(tokenIds[0], 1);
        assertEq(proxy.balanceOf(owner, 1), 10);
        assertTrue(proxy.isConsumable(1));
        assertTrue(proxy.isFractionable(1)); // Should be fractionable now
        
        vm.stopPrank();
    }
    
    function testMintMultipleTokens() public {
        vm.startPrank(owner);
        
        // Create test data for 3 tokens
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 5;
        amounts[2] = 1;
        
        string[] memory cids = new string[](3);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";
        cids[2] = "QmTest3";
        
        bool[] memory consumable = new bool[](3);
        consumable[0] = true;
        consumable[1] = true;
        consumable[2] = false;
        
        // Mint tokens
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        // Verify results
        assertEq(tokenIds.length, 3);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertEq(tokenIds[2], 3);
        
        // Check first token
        assertEq(proxy.balanceOf(owner, 1), 1);
        assertTrue(proxy.isConsumable(1));
        assertFalse(proxy.isFractionable(1));
        
        // Check second token (fractionable)
        assertEq(proxy.balanceOf(owner, 2), 5);
        assertTrue(proxy.isConsumable(2));
        assertTrue(proxy.isFractionable(2));
        
        // Check third token (not consumable)
        assertEq(proxy.balanceOf(owner, 3), 1);
        assertFalse(proxy.isConsumable(3));
        assertFalse(proxy.isFractionable(3));
        
        vm.stopPrank();
    }
    
    function testCannotMintWithZeroAmount() public {
        vm.startPrank(owner);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0; // Zero amount, should revert
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        vm.expectRevert(abi.encodeWithSignature("ZeroMintAmount()"));
        proxy.mint(amounts, cids, consumable);
        
        vm.stopPrank();
    }
    
    function testCannotMintWithMismatchedArrays() public {
        vm.startPrank(owner);
        
        // Create mismatched arrays
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;
        
        string[] memory cids = new string[](1); // Only one CID
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](2);
        consumable[0] = true;
        consumable[1] = false;
        
        vm.expectRevert(abi.encodeWithSignature("InvalidBatchInput()"));
        proxy.mint(amounts, cids, consumable);
        
        vm.stopPrank();
    }
    
    function testCannotMintFromNonOwner() public {
        vm.startPrank(user1);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.mint(amounts, cids, consumable);
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                            URI TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testTokenURI() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Check URI
        string memory tokenURI = proxy.uri(tokenId);
        assertEq(tokenURI, string(abi.encodePacked("ipfs://", TEST_CID)));
        
        vm.stopPrank();
    }
    
    function testHttpUriWithNoGateway() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // HTTP URI should be empty when no gateway is set
        assertEq(proxy.httpUri(tokenId), "");
        
        vm.stopPrank();
    }
    
    function testHttpUriWithGateway() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Set HTTP gateway
        vm.expectEmit(true, true, true, true);
        emit HttpGatewayUpdated(TEST_GATEWAY);
        proxy.setHttpGateway(TEST_GATEWAY);
        assertEq(proxy.httpGateway(), TEST_GATEWAY);
        
        // Check HTTP URI
        string memory expectedUri = string(abi.encodePacked(TEST_GATEWAY, "1.json"));
        assertEq(proxy.httpUri(tokenId), expectedUri);
        
        vm.stopPrank();
    }
    
    function testCannotGetURIForNonExistentToken() public {
        vm.expectRevert(abi.encodeWithSignature("TokenNotExists(uint256)", 999));
        proxy.uri(999);
        
        vm.expectRevert(abi.encodeWithSignature("TokenNotExists(uint256)", 999));
        proxy.httpUri(999);
    }
    
    /*//////////////////////////////////////////////////////////////
                         CONSUMPTION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testConsumeNonFractionableToken() public {
        vm.startPrank(owner);
        
        // Mint a non-fractionable token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Consume token
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 1;
        
        vm.expectEmit(true, true, true, true);
        emit TokenConsumed(tokenId, 1);
        
        vm.expectEmit(true, true, true, true);
        emit TokensBatchConsumed(consumeIds, consumeAmounts);
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Check token is marked as consumed but still exists
        assertTrue(proxy.isConsumed(tokenId));
        assertEq(proxy.balanceOf(owner, tokenId), 1); // Balance remains unchanged
        
        vm.stopPrank();
    }
    
    function testConsumeFractionableToken() public {
        vm.startPrank(owner);
        
        // Mint a fractionable token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Consume part of the token
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 3; // Consume 3 out of 10
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Check token is not marked as consumed and balance has decreased
        assertFalse(proxy.isConsumed(tokenId));
        assertEq(proxy.balanceOf(owner, tokenId), 7); // 10 - 3 = 7
        
        vm.stopPrank();
    }
    
    function testConsumeMultipleTokens() public {
        vm.startPrank(owner);
        
        // Mint multiple tokens
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1; // Non-fractionable
        amounts[1] = 5; // Fractionable
        
        string[] memory cids = new string[](2);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";
        
        bool[] memory consumable = new bool[](2);
        consumable[0] = true;
        consumable[1] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        // Consume tokens
        uint256[] memory consumeIds = new uint256[](2);
        consumeIds[0] = tokenIds[0]; // Non-fractionable
        consumeIds[1] = tokenIds[1]; // Fractionable
        
        uint256[] memory consumeAmounts = new uint256[](2);
        consumeAmounts[0] = 1;
        consumeAmounts[1] = 2; // Consume 2 out of 5
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Check results
        assertTrue(proxy.isConsumed(tokenIds[0])); // Non-fractionable is marked consumed
        assertEq(proxy.balanceOf(owner, tokenIds[0]), 1); // Balance unchanged
        
        assertFalse(proxy.isConsumed(tokenIds[1])); // Fractionable is not marked consumed
        assertEq(proxy.balanceOf(owner, tokenIds[1]), 3); // 5 - 2 = 3
        
        vm.stopPrank();
    }
    
    function testCannotConsumeNonConsumableToken() public {
        vm.startPrank(owner);
        
        // Mint a non-consumable token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = false; // Not consumable
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Try to consume token
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 1;
        
        vm.expectRevert(abi.encodeWithSignature("TokenNotConsumable(uint256)", tokenId));
        proxy.consume(consumeIds, consumeAmounts);
        
        vm.stopPrank();
    }
    
    function testCannotConsumeAlreadyConsumedToken() public {
        vm.startPrank(owner);
        
        // Mint a consumable token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Consume token
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 1;
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Try to consume again
        vm.expectRevert(abi.encodeWithSignature("TokenAlreadyConsumed(uint256)", tokenId));
        proxy.consume(consumeIds, consumeAmounts);
        
        vm.stopPrank();
    }
    
    function testCannotConsumeMoreThanBalance() public {
        vm.startPrank(owner);
        
        // Mint a fractionable token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Try to consume more than available
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 10; // More than the 5 available
        
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance(uint256,uint256,uint256)", tokenId, 10, 5));
        proxy.consume(consumeIds, consumeAmounts);
        
        vm.stopPrank();
    }
    
    function testCannotConsumeFromNonOwner() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        vm.stopPrank();
        
        // Try to consume as non-owner
        vm.startPrank(user1);
        
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenIds[0];
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 1;
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.consume(consumeIds, consumeAmounts);
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                         STATUS UPDATE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testUpdateStatus() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Update status
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenId;
        
        string[] memory statuses = new string[](1);
        statuses[0] = TEST_STATUS;
        
        uint40 timestamp = uint40(block.timestamp);
        
        vm.expectEmit(true, true, true, true);
        emit StatusUpdated(tokenId, TEST_STATUS, timestamp);
        
        vm.expectEmit(true, true, true, true);
        emit StatusesBatchUpdated(updateIds, statuses, timestamp);
        
        proxy.update(updateIds, statuses);
        
        // Check status was updated
        Crurated.Status memory currentStatus = proxy.getCurrentStatus(tokenId);
        assertEq(currentStatus.status, TEST_STATUS);
        assertEq(currentStatus.timestamp, timestamp);
        
        // Check provenance
        Crurated.Status[] memory provenance = proxy.getProvenance(tokenId);
        assertEq(provenance.length, 1);
        assertEq(provenance[0].status, TEST_STATUS);
        assertEq(provenance[0].timestamp, timestamp);
        
        vm.stopPrank();
    }
    
    function testUpdateStatusMultipleTimes() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Update status multiple times
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenId;
        
        // First update
        string[] memory statuses1 = new string[](1);
        statuses1[0] = "Produced";
        proxy.update(updateIds, statuses1);
        
        // Second update - advance block timestamp
        vm.warp(block.timestamp + 1 days);
        string[] memory statuses2 = new string[](1);
        statuses2[0] = "Shipped";
        proxy.update(updateIds, statuses2);
        
        // Third update - advance block timestamp
        vm.warp(block.timestamp + 1 days);
        string[] memory statuses3 = new string[](1);
        statuses3[0] = "Delivered";
        proxy.update(updateIds, statuses3);
        
        // Check current status
        Crurated.Status memory currentStatus = proxy.getCurrentStatus(tokenId);
        assertEq(currentStatus.status, "Delivered");
        
        // Check provenance history
        Crurated.Status[] memory provenance = proxy.getProvenance(tokenId);
        assertEq(provenance.length, 3);
        assertEq(provenance[0].status, "Produced");
        assertEq(provenance[1].status, "Shipped");
        assertEq(provenance[2].status, "Delivered");
        
        vm.stopPrank();
    }
    
    function testUpdateMultipleTokens() public {
        vm.startPrank(owner);
        
        // Mint multiple tokens
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        
        string[] memory cids = new string[](2);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";
        
        bool[] memory consumable = new bool[](2);
        consumable[0] = true;
        consumable[1] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        // Update status for multiple tokens
        uint256[] memory updateIds = new uint256[](2);
        updateIds[0] = tokenIds[0];
        updateIds[1] = tokenIds[1];
        
        string[] memory statuses = new string[](2);
        statuses[0] = "Status 1";
        statuses[1] = "Status 2";
        
        proxy.update(updateIds, statuses);
        
        // Check statuses
        Crurated.Status memory status1 = proxy.getCurrentStatus(tokenIds[0]);
        assertEq(status1.status, "Status 1");
        
        Crurated.Status memory status2 = proxy.getCurrentStatus(tokenIds[1]);
        assertEq(status2.status, "Status 2");
        
        vm.stopPrank();
    }
    
    function testCannotUpdateWithEmptyStatus() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Try to update with empty status
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenId;
        
        string[] memory statuses = new string[](1);
        statuses[0] = ""; // Empty status
        
        vm.expectRevert(abi.encodeWithSignature("EmptyStatus()"));
        proxy.update(updateIds, statuses);
        
        vm.stopPrank();
    }
    
    function testCannotUpdateNonExistentToken() public {
        vm.startPrank(owner);
        
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = 999; // Non-existent token
        
        string[] memory statuses = new string[](1);
        statuses[0] = TEST_STATUS;
        
        vm.expectRevert(abi.encodeWithSignature("TokenNotExists(uint256)", 999));
        proxy.update(updateIds, statuses);
        
        vm.stopPrank();
    }
    
    function testCannotUpdateFromNonOwner() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        vm.stopPrank();
        
        // Try to update as non-owner
        vm.startPrank(user1);
        
        uint256[] memory updateIds = new uint256[](1);
        updateIds[0] = tokenIds[0];
        
        string[] memory statuses = new string[](1);
        statuses[0] = TEST_STATUS;
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.update(updateIds, statuses);
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                         METADATA TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSetTokenCID() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Set new CID
        string memory newCID = "QmNewCID";
        
        vm.expectEmit(true, true, true, true);
        emit TokenMetadataUpdated(tokenId, newCID);
        proxy.setTokenCID(tokenId, newCID);
        
        // Check URI has been updated
        string memory tokenURI = proxy.uri(tokenId);
        assertEq(tokenURI, string(abi.encodePacked("ipfs://", newCID)));
        
        vm.stopPrank();
    }
    
    function testCannotSetCIDForNonExistentToken() public {
        vm.startPrank(owner);
        
        vm.expectRevert(abi.encodeWithSignature("TokenNotExists(uint256)", 999));
        proxy.setTokenCID(999, "QmNewCID");
        
        vm.stopPrank();
    }
    
    function testCannotSetCIDFromNonOwner() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        vm.stopPrank();
        
        // Try to set CID as non-owner
        vm.startPrank(user1);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.setTokenCID(tokenIds[0], "QmNewCID");
        
        vm.stopPrank();
    }
    
    function testSetHttpGateway() public {
        vm.startPrank(owner);
        
        // Set HTTP gateway
        string memory newGateway = "https://example.com/tokens/";
        
        vm.expectEmit(true, true, true, true);
        emit HttpGatewayUpdated(newGateway);
        
        proxy.setHttpGateway(newGateway);
        assertEq(proxy.httpGateway(), newGateway);
        
        // Set to empty string
        proxy.setHttpGateway("");
        assertEq(proxy.httpGateway(), "");
        
        vm.stopPrank();
    }
    
    function testCannotSetHttpGatewayFromNonOwner() public {
        vm.startPrank(user1);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.setHttpGateway(TEST_GATEWAY);
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                         SOULBOUND TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testTransferNonConsumedToken() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Transfer the token to user1
        proxy.safeTransferFrom(owner, user1, tokenId, 1, "");
        
        // Check balances
        assertEq(proxy.balanceOf(owner, tokenId), 0);
        assertEq(proxy.balanceOf(user1, tokenId), 1);
        
        vm.stopPrank();
    }
    
    function testCannotTransferConsumedToken() public {
        vm.startPrank(owner);
        
        // Mint a token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Consume the token
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 1;
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Try to transfer the consumed token
        vm.expectRevert(abi.encodeWithSignature("TokenSoulbound()"));
        proxy.safeTransferFrom(owner, user1, tokenId, 1, "");
        
        vm.stopPrank();
    }
    
    function testBatchTransferNonConsumedTokens() public {
        vm.startPrank(owner);
        
        // Mint multiple tokens
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        
        string[] memory cids = new string[](2);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";
        
        bool[] memory consumable = new bool[](2);
        consumable[0] = true;
        consumable[1] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        // Batch transfer the tokens to user1
        uint256[] memory transferIds = new uint256[](2);
        transferIds[0] = tokenIds[0];
        transferIds[1] = tokenIds[1];
        
        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        
        proxy.safeBatchTransferFrom(owner, user1, transferIds, transferAmounts, "");
        
        // Check balances
        assertEq(proxy.balanceOf(owner, tokenIds[0]), 0);
        assertEq(proxy.balanceOf(user1, tokenIds[0]), 1);
        assertEq(proxy.balanceOf(owner, tokenIds[1]), 0);
        assertEq(proxy.balanceOf(user1, tokenIds[1]), 1);
        
        vm.stopPrank();
    }
    
    function testCannotBatchTransferWithConsumedToken() public {
        vm.startPrank(owner);
        
        // Mint multiple tokens
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;
        
        string[] memory cids = new string[](2);
        cids[0] = "QmTest1";
        cids[1] = "QmTest2";
        
        bool[] memory consumable = new bool[](2);
        consumable[0] = true;
        consumable[1] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        // Consume one token
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenIds[0];
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 1;
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Try to batch transfer including the consumed token
        uint256[] memory transferIds = new uint256[](2);
        transferIds[0] = tokenIds[0]; // Consumed
        transferIds[1] = tokenIds[1]; // Not consumed
        
        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 1;
        transferAmounts[1] = 1;
        
        vm.expectRevert(abi.encodeWithSignature("TokenSoulbound()"));
        proxy.safeBatchTransferFrom(owner, user1, transferIds, transferAmounts, "");
        
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
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], 1);
        
        vm.stopPrank();
    }
    
    function testCannotUpgradeFromNonOwner() public {
        vm.startPrank(user1);
        
        // Deploy new implementation
        Crurated newImplementation = new Crurated();
        
        // Try to upgrade from non-owner
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        proxy.upgradeToAndCall(address(newImplementation), "");
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                           EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testConsumeFractionableTokenCompletely() public {
        vm.startPrank(owner);
        
        // Mint a fractionable token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 5;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Consume the entire token
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = 5; // Consume all 5
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Check balance is now zero
        assertEq(proxy.balanceOf(owner, tokenId), 0);
        
        // The token itself is not marked as consumed since it's fractionable
        assertFalse(proxy.isConsumed(tokenId));
        
        vm.stopPrank();
    }
    
    function testConsecutiveMinting() public {
        vm.startPrank(owner);
        
        // First mint
        uint256[] memory amounts1 = new uint256[](1);
        amounts1[0] = 1;
        
        string[] memory cids1 = new string[](1);
        cids1[0] = "QmTest1";
        
        bool[] memory consumable1 = new bool[](1);
        consumable1[0] = true;
        
        uint256[] memory tokenIds1 = proxy.mint(amounts1, cids1, consumable1);
        
        // Second mint
        uint256[] memory amounts2 = new uint256[](1);
        amounts2[0] = 1;
        
        string[] memory cids2 = new string[](1);
        cids2[0] = "QmTest2";
        
        bool[] memory consumable2 = new bool[](1);
        consumable2[0] = true;
        
        uint256[] memory tokenIds2 = proxy.mint(amounts2, cids2, consumable2);
        
        // Check token IDs are incrementing
        assertEq(tokenIds1[0], 1);
        assertEq(tokenIds2[0], 2);
        
        vm.stopPrank();
    }
    
    function testMintZeroTokens() public {
        vm.startPrank(owner);
        
        // Try to mint with empty arrays
        uint256[] memory amounts = new uint256[](0);
        string[] memory cids = new string[](0);
        bool[] memory consumable = new bool[](0);
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        // Should return empty array
        assertEq(tokenIds.length, 0);
        
        vm.stopPrank();
    }
    
    function testFuzzMinting(uint256 amount, bool isConsumable) public {
        // Bound amount to reasonable values to avoid overflow
        amount = bound(amount, 1, 1000000);
        
        vm.startPrank(owner);
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = isConsumable;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        
        assertEq(tokenIds.length, 1);
        assertEq(tokenIds[0], 1);
        assertEq(proxy.balanceOf(owner, tokenIds[0]), amount);
        assertEq(proxy.isConsumable(tokenIds[0]), isConsumable);
        assertEq(proxy.isFractionable(tokenIds[0]), amount > 1);
        
        vm.stopPrank();
    }
    
    function testFuzzConsumption(uint256 mintAmount, uint256 consumeAmount) public {
        // Bound amounts to avoid overflow and ensure mintAmount >= consumeAmount
        mintAmount = bound(mintAmount, 2, 1000000);
        consumeAmount = bound(consumeAmount, 1, mintAmount - 1); // Ensure we don't consume everything
        
        vm.startPrank(owner);
        
        // Mint token
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = mintAmount;
        
        string[] memory cids = new string[](1);
        cids[0] = TEST_CID;
        
        bool[] memory consumable = new bool[](1);
        consumable[0] = true;
        
        uint256[] memory tokenIds = proxy.mint(amounts, cids, consumable);
        uint256 tokenId = tokenIds[0];
        
        // Consume partial amount
        uint256[] memory consumeIds = new uint256[](1);
        consumeIds[0] = tokenId;
        
        uint256[] memory consumeAmounts = new uint256[](1);
        consumeAmounts[0] = consumeAmount;
        
        proxy.consume(consumeIds, consumeAmounts);
        
        // Check remaining balance
        assertEq(proxy.balanceOf(owner, tokenId), mintAmount - consumeAmount);
        
        vm.stopPrank();
    }
}