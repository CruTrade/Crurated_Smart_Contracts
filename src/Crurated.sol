// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {CruratedBase} from "./abstracts/CruratedBase.sol";

/**
 * @title Crurated
 * @author mazzacash (https://linkedin.com/in/mazzacash/)
 * @notice Soulbound ERC1155 collectibles with dynamic status tracking
 * @dev Gas-optimized batch operations, historical migration, upgradeable architecture
 * @custom:security-contact security@crurated.com
 */
contract Crurated is CruratedBase {
    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploy contract and disable initializers
     * @dev UUPS proxy pattern - use initialize() after deployment
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize contract with owner
     * @param owner Address with administrative control
     */
    function initialize(address owner) external initializer {
        __CruratedBase_init(owner);
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pause all operations (emergency)
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resume normal operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Register new status type
     * @param name Human readable status name
     * @return statusId Assigned identifier
     */
    function addStatus(string calldata name) external onlyOwner returns (uint8 statusId) {
        return _registerStatus(name);
    }

    /*//////////////////////////////////////////////////////////////
                                TOKEN OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Migrate tokens with complete historical data
     * @dev Atomic creation + full provenance history in one transaction
     * @param cids IPFS content identifiers
     * @param amounts Quantities to mint per token
     * @param statuses Historical status arrays per token
     * @return tokenIds Created token identifiers
     */
    function migrate(
        string[] calldata cids,
        uint256[] calldata amounts,
        Status[][] calldata statuses
    ) external onlyOwner whenNotPaused returns (uint256[] memory tokenIds) {
        uint256 length = cids.length;
        if (length == 0 || length != amounts.length || length != statuses.length) 
            revert InvalidBatchInput();

        tokenIds = new uint256[](length);
        uint256[] memory mintAmounts = new uint256[](length);
        address owner_ = owner();

        // Process each token with historical timeline
        for (uint256 i; i < length;) {
            (tokenIds[i], mintAmounts[i]) = _processMigration(cids[i], amounts[i], statuses[i]);
            unchecked { ++i; }
        }

        // Batch mint all migrated tokens
        _mintBatch(owner_, tokenIds, mintAmounts, "");
        return tokenIds;
    }

    /**
     * @notice Create new tokens with metadata
     * @dev Standard token creation for normal operations
     * @param cids IPFS content identifiers
     * @param amounts Quantities to mint per token
     * @return tokenIds Created token identifiers
     */
    function mint(
        string[] calldata cids,
        uint256[] calldata amounts
    ) external onlyOwner whenNotPaused returns (uint256[] memory tokenIds) {
        uint256 length = cids.length;
        if (length == 0 || length != amounts.length) revert InvalidBatchInput();

        tokenIds = new uint256[](length);
        uint256[] memory mintAmounts = new uint256[](length);
        address owner_ = owner();

        // Process new token creation
        for (uint256 i; i < length;) {
            (tokenIds[i], mintAmounts[i]) = _processMint(cids[i], amounts[i]);
            unchecked { ++i; }
        }

        // Batch mint all new tokens
        _mintBatch(owner_, tokenIds, mintAmounts, "");
        return tokenIds;
    }

    /*//////////////////////////////////////////////////////////////
                                STATUS OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update token statuses with custom timestamps
     * @dev Apply status changes with precise timing control
     * @param tokenIds Tokens to update
     * @param statuses Status data to apply
     */
    function update(
        uint256[] calldata tokenIds,
        Status[] calldata statuses
    ) external onlyOwner whenNotPaused {
        uint256 length = tokenIds.length;
        if (length == 0 || length != statuses.length) revert InvalidBatchInput();

        // Apply each status update
        for (uint256 i; i < length;) {
            Status calldata status = statuses[i];
            _addStatus(tokenIds[i], status.statusId, status.reason, status.timestamp);
            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                METADATA OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update token metadata
     * @dev Batch update IPFS content identifiers
     * @param tokenIds Tokens to update
     * @param newCids New IPFS CIDs
     */
    function setCIDs(
        uint256[] calldata tokenIds,
        string[] calldata newCids
    ) external onlyOwner whenNotPaused {
        uint256 length = tokenIds.length;
        if (length == 0 || length != newCids.length) revert InvalidBatchInput();

        // Update each token metadata
        for (uint256 i; i < length;) {
            _updateMetadata(tokenIds[i], newCids[i]);
            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                SOULBOUND OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer blocked - tokens are soulbound
     */
    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override {
        revert TokenSoulbound();
    }

    /**
     * @notice Batch transfer blocked - tokens are soulbound
     */
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override {
        revert TokenSoulbound();
    }

    /**
     * @notice Approval blocked - tokens are soulbound
     */
    function setApprovalForAll(address, bool) public pure override {
        revert TokenSoulbound();
    }
}