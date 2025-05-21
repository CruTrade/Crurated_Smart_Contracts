// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {CruratedBase} from "./abstracts/CruratedBase.sol";

/**
 * @title Crurated (https://crurated.com/)
 * @author mazzacash (https://linkedin.com/in/mazzacash/)
 * @notice Premium ERC1155 token implementation for collectibles with provenance tracking
 * @dev Implements soulbound tokens with comprehensive features:
 *      - Batch minting operations for efficient token creation
 *      - Historical provenance tracking with timestamped status records
 *      - Automated metadata generation with IPFS integration
 *      - Protocol-level pause functionality for emergency situations
 *      - Upgradeable architecture for future improvements
 *      - Gas-optimized batch operations for all major functions
 *
 *      Tokens created by this contract are permanently attached to their original
 *      owner (soulbound) through direct blocking of transfer functions, while
 *      maintaining full compatibility with ERC1155 standards for viewing and
 *      querying operations.
 *
 * @custom:security-contact security@crurated.com
 */
contract Crurated is CruratedBase {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Constructor disables initializers to prevent implementation contract initialization
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract (replaces constructor for upgradeable contracts)
     * @param owner Address that will own the contract
     */
    function initialize(address owner) external initializer {
        __CruratedBase_init(owner);
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses all token operations
     * @dev Can only be called by the contract owner
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses all token operations
     * @dev Can only be called by the contract owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Sets HTTP gateway for metadata access
     * @param newGateway New gateway URL
     */
    function setHttpGateway(string calldata newGateway) external onlyOwner {
        // Update HTTP gateway
        _httpGateway = newGateway;
        emit HttpGatewayUpdated(newGateway);
    }

    /*//////////////////////////////////////////////////////////////
                              TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new tokens with metadata (batch operation)
     * @param cids Array of IPFS CIDs for token metadata
     * @param amounts Array of token amounts
     * @return tokenIds Array of newly minted token IDs
     */
    function mint(
        string[] calldata cids,
        uint256[] calldata amounts
    ) external onlyOwner whenNotPaused returns (uint256[] memory tokenIds) {
        // Validate inputs
        uint256 length = cids.length;
        if (length == 0 || length != amounts.length) revert InvalidBatchInput();

        // Prepare arrays for batch mint
        tokenIds = new uint256[](length);
        uint256[] memory mintAmounts = new uint256[](length);
        address owner_ = owner();

        // Process each token in the batch
        for (uint256 i; i < length; ) {
            (tokenIds[i], mintAmounts[i]) = _processMint(cids[i], amounts[i]);

            unchecked {
                ++i;
            }
        }

        // Execute batch mint operation
        _mintBatch(owner_, tokenIds, mintAmounts, "");
    }

    /**
     * @dev Process a single token mint within a batch
     * @param cid IPFS CID for token metadata
     * @param amount Token amount to mint
     * @return tokenId The new token ID
     * @return mintAmount The amount being minted
     */
    function _processMint(
        string calldata cid,
        uint256 amount
    ) private returns (uint256 tokenId, uint256 mintAmount) {
        // Validate amount
        if (amount == 0) revert ZeroMintAmount();

        // Create new token
        tokenId = _createToken(cid);

        return (tokenId, amount);
    }

    /**
     * @notice Imports tokens with historical provenance data (batch operation)
     * @param data Array of token data for import
     * @return tokenIds Array of imported token IDs
     */
    function migrate(
        Data[] calldata data
    ) external onlyOwner whenNotPaused returns (uint256[] memory tokenIds) {
        // Validate input
        uint256 length = data.length;
        if (length == 0) revert InvalidBatchInput();

        // Prepare arrays for batch mint
        tokenIds = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);
        address owner_ = owner();

        // Process each token in the batch
        for (uint256 i; i < length; ) {
            (tokenIds[i], amounts[i]) = _processMigration(data[i]);

            unchecked {
                ++i;
            }
        }

        // Execute batch mint operation
        _mintBatch(owner_, tokenIds, amounts, "");
    }

    /**
     * @dev Process a single token migration within a batch
     * @param data Token data for migration
     * @return tokenId The new token ID
     * @return mintAmount The amount being minted
     */
    function _processMigration(
        Data calldata data
    ) private returns (uint256 tokenId, uint256 mintAmount) {
        // Validate migration data
        if (data.amount == 0) revert ZeroMintAmount();
        if (data.timestamps.length != data.statuses.length)
            revert InvalidBatchInput();

        // Create new token
        tokenId = _createToken(data.cid);

        // Process historical statuses
        uint256 length = data.statuses.length;
        if (length > 0) {
            for (uint256 i; i < length; ) {
                _addStatus(tokenId, data.statuses[i], data.timestamps[i]);

                unchecked {
                    ++i;
                }
            }
        }

        return (tokenId, data.amount);
    }

    /*//////////////////////////////////////////////////////////////
                             STATUS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates status for multiple tokens with current timestamp
     * @param tokenIds Array of token IDs
     * @param statuses Array of status messages
     */
    function updateCurrentStatus(
        uint256[] calldata tokenIds,
        string[] calldata statuses
    ) external onlyOwner whenNotPaused {
        // Validate inputs
        uint256 length = tokenIds.length;
        if (length == 0 || length != statuses.length)
            revert InvalidBatchInput();

        uint40 timestamp = uint40(block.timestamp);

        // Process each status update in the batch
        for (uint256 i; i < length; ) {
            _addStatus(tokenIds[i], statuses[i], timestamp);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Updates status for tokens with historical timestamps
     * @param tokenIds Array of token IDs
     * @param statuses Array of status messages
     * @param timestamps Array of status timestamps
     */
    function updateHistoricalStatus(
        uint256[] calldata tokenIds,
        string[] calldata statuses,
        uint40[] calldata timestamps
    ) external onlyOwner whenNotPaused {
        // Validate inputs
        uint256 length = tokenIds.length;
        if (
            length == 0 ||
            length != statuses.length ||
            length != timestamps.length
        ) revert InvalidBatchInput();

        // Process each status update in the batch
        for (uint256 i; i < length; ) {
            _addStatus(tokenIds[i], statuses[i], timestamps[i]);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates metadata CIDs for multiple tokens (batch operation)
     * @param tokenIds Array of token IDs
     * @param newCids Array of new IPFS CIDs
     */
    function setCIDs(
        uint256[] calldata tokenIds,
        string[] calldata newCids
    ) external onlyOwner whenNotPaused {
        // Validate inputs
        uint256 length = tokenIds.length;
        if (length == 0 || length != newCids.length) revert InvalidBatchInput();

        // Process each metadata update in the batch
        for (uint256 i; i < length; ) {
            _updateMetadata(tokenIds[i], newCids[i]);

            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                          TRANSFER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Overrides ERC1155 transfer function to make tokens non-transferable
     * @dev Reverts all transfer attempts with a clear error message
     */
    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override {
        revert TokenSoulbound();
    }

    /**
     * @notice Overrides ERC1155 batch transfer function to make tokens non-transferable
     * @dev Reverts all batch transfer attempts with a clear error message
     */
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override {
        revert TokenSoulbound();
    }
}
