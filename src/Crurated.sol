// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

/**
 * @title Crurated (https://www.crurated.com/)
 * @author mazzaca$h (https://www.linkedin.com/in/mazzacash/)
 * @notice ERC1155 upgradeable token standard tailored for fine-grained consumption, provenance tracking, and dynamic metadata resolution.
 * 
 * @dev Core Features:
 * 
 * - 🔁 **Multi-Asset Support**: Fully compliant with ERC1155. Handles both fungible tokens (quantity > 1) and NFTs (quantity = 1).
 * - 🧩 **Fractional Consumption**: Assets can be partially or fully consumed. Consumption may optionally burn tokens or flag them as used.
 * - 🔒 **Soulbound Mechanics**: Consumed tokens become non-transferable, enforcing lifecycle integrity.
 * - 📜 **Provenance Tracking**: Every status change (e.g., consumed, transferred) is logged immutably with timestamp and metadata, per token ID and per owner.
 * - 🌐 **Dual Metadata URI System**:
 *      - Default base URI (HTTP or IPFS).
 *      - Optional per-token redirect with override capability.
 *      - Ensures compatibility with decentralized and centralized metadata schemes.
 * - 🛡️ **Access Control**: Restricted minting, consumption, and administrative operations using `onlyOwner` or designated roles.
 * - 🔄 **Upgradeable Architecture**: Built with UUPS proxy pattern via OpenZeppelin upgradeable libraries. Ensures secure, modular contract evolution.
 * - ⚠️ **Custom Errors & Event Logging**: Gas-efficient error handling and event emission for all state-changing actions.
 * - 🧪 **Robust Input Validation**: Comprehensive guards against invalid operations across all exposed methods.
 * 
 * @custom:security-contact security@crurated.com
 */
contract Crurated is
    ERC1155Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Name of the token collection
     */
    string public constant NAME = "Crurated";
    
    /**
     * @dev Symbol of the token collection
     */
    string public constant SYMBOL = "CRURATED";

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Status update in the provenance history
     * @param status Description of the current status
     * @param timestamp Unix timestamp when the status was updated
     */
    struct Status {
        string status;   // Status description
        uint40 timestamp; // Timestamp of update
    }

    /**
     * @dev Complete token data structure containing all token properties
     * @param cid IPFS Content Identifier for token metadata
     * @param consumed Flag indicating if token has been consumed
     * @param consumable Flag indicating if token can be consumed
     * @param fractionable Flag indicating if token can be partially consumed (quantity > 1)
     * @param provenance Array of status updates tracking the token's history
     */
    struct Data {
        string cid;       // IPFS CID for token metadata
        bool consumed;    // Whether the token has been consumed
        bool consumable;  // Whether the token can be consumed
        bool fractionable; // Whether the token can be partially consumed (quantity > 1)
        Status[] provenance; // Complete provenance history
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev HTTP gateway base URL for redirecting to IPFS content
     * @notice This is used to create HTTP accessible links to the token metadata
     */
    string private _httpGateway;

    /**
     * @dev Mapping from token ID to token data
     * @notice Stores all metadata and state for each token
     */
    mapping(uint256 => Data) private _tokenData;

    /**
     * @dev Counter for token IDs
     * @notice Used to generate sequential and unique token IDs 
     */
    CountersUpgradeable.Counter private _tokenIds;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Thrown when attempting to set an empty status string
     */
    error EmptyStatus();
    
    /**
     * @dev Thrown when attempting to mint with zero amount
     */
    error ZeroMintAmount();
    
    /**
     * @dev Thrown when attempting to transfer a consumed (soulbound) token
     */
    error TokenSoulbound();
    
    /**
     * @dev Thrown when input arrays have mismatching lengths
     */
    error InvalidBatchInput();
    
    /**
     * @dev Thrown when operating on a non-existent token
     * @param tokenId The ID of the token that doesn't exist
     */
    error TokenNotExists(uint256 tokenId);
    
    /**
     * @dev Thrown when attempting to consume a non-consumable token
     * @param tokenId The ID of the non-consumable token
     */
    error TokenNotConsumable(uint256 tokenId);
    
    /**
     * @dev Thrown when attempting to consume an already consumed token
     * @param tokenId The ID of the already consumed token
     */
    error TokenAlreadyConsumed(uint256 tokenId);
    
    /**
     * @dev Thrown when attempting to consume more tokens than available
     * @param tokenId The ID of the token
     * @param requested The amount requested to consume
     * @param available The actual available amount
     */
    error InsufficientBalance(
        uint256 tokenId,
        uint256 requested,
        uint256 available
    );

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emitted when a token is minted
     * @param tokenId ID of the minted token
     * @param amount Amount of tokens minted
     * @param consumable Whether the token is consumable
     * @param fractionable Whether the token is fractionable
     */
    event TokenMinted(
        uint256 indexed tokenId,
        uint256 amount,
        bool consumable,
        bool fractionable
    );
    
    /**
     * @dev Emitted when multiple tokens are minted in a batch
     * @param tokenIds Array of IDs of minted tokens
     * @param amounts Array of amounts minted for each token
     * @param consumable Array of flags indicating if each token is consumable
     * @param fractionable Array of flags indicating if each token is fractionable
     */
    event TokensBatchMinted(
        uint256[] tokenIds,
        uint256[] amounts,
        bool[] consumable,
        bool[] fractionable
    );

    /**
     * @dev Emitted when a token's status is updated
     * @param tokenId ID of the updated token
     * @param status New status string
     * @param timestamp Time when the status was updated
     */
    event StatusUpdated(
        uint256 indexed tokenId,
        string status,
        uint40 timestamp
    );
    
    /**
     * @dev Emitted when multiple tokens' statuses are updated in a batch
     * @param tokenIds Array of token IDs that were updated
     * @param statuses Array of new status strings
     * @param timestamp Time when the statuses were updated
     */
    event StatusesBatchUpdated(
        uint256[] tokenIds,
        string[] statuses,
        uint40 timestamp
    );

    /**
     * @dev Emitted when the HTTP gateway URL is updated
     * @param newGateway New HTTP gateway URL
     */
    event HttpGatewayUpdated(string newGateway);
    
    /**
     * @dev Emitted when a token is consumed
     * @param tokenId ID of the consumed token
     * @param amount Amount of tokens consumed
     */
    event TokenConsumed(uint256 indexed tokenId, uint256 amount);
    
    /**
     * @dev Emitted when multiple tokens are consumed in a batch
     * @param tokenIds Array of consumed token IDs
     * @param amounts Array of amounts consumed for each token
     */
    event TokensBatchConsumed(uint256[] tokenIds, uint256[] amounts);
    
    /**
     * @dev Emitted when a token's metadata CID is updated
     * @param tokenId ID of the token with updated metadata
     * @param newCid New IPFS CID for the token's metadata
     */
    event TokenMetadataUpdated(uint256 indexed tokenId, string newCid);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Constructor for the implementation contract
     * @notice Disables initializers to prevent the implementation from being initialized
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract
     * @param owner Initial owner of the contract
     * @dev Sets up the ERC1155, Ownable, and UUPS modules
     *      This function replaces the constructor for upgradeable contracts
     *      and can only be called once
     */
    function initialize(address owner) external initializer {
        __ERC1155_init("ipfs://");
        __Ownable_init(owner);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets token URI in IPFS format
     * @param tokenId Token ID to query
     * @return string Token URI pointing to IPFS
     * @dev Returns the base URI combined with token's CID
     *      Reverts if the token does not exist
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return string(abi.encodePacked(super.uri(0), _tokenData[tokenId].cid));
    }

    /**
     * @notice Gets token URI in HTTP format
     * @param tokenId Token ID to query
     * @return string Token URI pointing to HTTP gateway
     * @dev Formats URI as httpGateway + tokenId + ".json"
     *      Reverts if the token does not exist
     *      Returns empty string if HTTP gateway is not set
     */
    function httpUri(uint256 tokenId) public view returns (string memory) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (bytes(_httpGateway).length == 0) return "";
        return
            string(abi.encodePacked(_httpGateway, tokenId.toString(), ".json"));
    }

    /**
     * @notice Checks if a token is consumable
     * @param tokenId Token ID to check
     * @return bool Whether the token can be consumed
     * @dev Reverts if the token does not exist
     */
    function isConsumable(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return _tokenData[tokenId].consumable;
    }

    /**
     * @notice Checks if a token has been consumed
     * @param tokenId Token ID to check
     * @return bool Whether the token has been consumed
     * @dev Reverts if the token does not exist
     */
    function isConsumed(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return _tokenData[tokenId].consumed;
    }

    /**
     * @notice Checks if a token is fractionable (can be partially consumed)
     * @param tokenId Token ID to check
     * @return bool Whether the token is fractionable
     * @dev Reverts if the token does not exist
     */
    function isFractionable(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return _tokenData[tokenId].fractionable;
    }

    /**
     * @notice Gets current status of a token
     * @param tokenId Token ID to query
     * @return Status Current status and timestamp
     * @dev Reverts if the token does not exist
     *      Returns the most recent status from the provenance array
     */
    function getCurrentStatus(uint256 tokenId)
        external
        view
        returns (Status memory)
    {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);

        Status[] storage provenance = _tokenData[tokenId].provenance;

        return provenance[provenance.length - 1];
    }

    /**
     * @notice Gets complete provenance history of a token
     * @param tokenId Token ID to query
     * @return Status[] Array of all status updates
     * @dev Reverts if the token does not exist
     */
    function getProvenance(uint256 tokenId)
        external
        view
        returns (Status[] memory)
    {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return _tokenData[tokenId].provenance;
    }

    /**
     * @notice Gets the HTTP gateway base URL used for token metadata
     * @return string The HTTP gateway base URL
     */
    function httpGateway() external view returns (string memory) {
        return _httpGateway;
    }

    /*//////////////////////////////////////////////////////////////
                              TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints new tokens
     * @param amounts Array of token amounts to mint
     * @param cids Array of IPFS CIDs for token metadata
     * @param areConsumable Array of flags indicating if tokens can be consumed
     * @return uint256[] Array of newly minted token IDs
     * @dev Only callable by owner
     *      Input arrays must have the same length
     *      Token amounts must be greater than zero
     *      Tokens with amount > 1 are automatically marked as fractionable
     */
    function mint(
        uint256[] calldata amounts,
        string[] calldata cids,
        bool[] calldata areConsumable
    ) external onlyOwner returns (uint256[] memory) {
        if (
            amounts.length != cids.length ||
            amounts.length != areConsumable.length
        ) revert InvalidBatchInput();

        uint256 length = amounts.length;

        uint256[] memory newTokenIds = new uint256[](length);
        bool[] memory fractionableFlags = new bool[](length);

        for (uint256 i; i < length; ) {
            uint256 amount = amounts[i];
            if (amount == 0) revert ZeroMintAmount();

            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            newTokenIds[i] = newTokenId;

            // A token is fractionable if its amount is greater than 1
            bool tokenIsFractionable = amount > 1;
            fractionableFlags[i] = tokenIsFractionable;

            _mint(owner(), newTokenId, amount, "");

            // Initialize token data in storage
            _tokenData[newTokenId].consumable = areConsumable[i];
            _tokenData[newTokenId].fractionable = tokenIsFractionable;
            _tokenData[newTokenId].cid = cids[i];
            // consumed is false by default
            // provenance array is empty by default

            unchecked {
                ++i;
            }
        }

        emit TokensBatchMinted(
            newTokenIds,
            amounts,
            areConsumable,
            fractionableFlags
        );
        return newTokenIds;
    }

    /**
     * @notice Consumes tokens - burns if fractionable, marks as consumed otherwise
     * @param tokenIds Array of token IDs to consume
     * @param amounts Array of amounts to consume (only relevant for fractionable tokens)
     * @dev Only callable by owner
     *      Input arrays must have the same length
     *      Tokens must be consumable and not already consumed
     *      For fractionable tokens, specified amount is burned
     *      For non-fractionable tokens, they are marked as consumed
     */
    function consume(uint256[] calldata tokenIds, uint256[] calldata amounts)
        external
        onlyOwner
    {
        if (tokenIds.length != amounts.length) revert InvalidBatchInput();

        uint256 length = tokenIds.length;
        address ownerAddress = owner();

        for (uint256 i; i < length; ) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            if (!_exists(tokenId)) revert TokenNotExists(tokenId);
            if (!_tokenData[tokenId].consumable)
                revert TokenNotConsumable(tokenId);
            if (_tokenData[tokenId].consumed)
                revert TokenAlreadyConsumed(tokenId);

            // Check if the token is fractionable
            if (_tokenData[tokenId].fractionable) {
                uint256 balance = balanceOf(ownerAddress, tokenId);
                if (amount > balance) {
                    revert InsufficientBalance(tokenId, amount, balance);
                }

                // Burn the specified amount from the fractionable token
                _burn(ownerAddress, tokenId, amount);
            } else {
                _tokenData[tokenId].consumed = true;
            }

            emit TokenConsumed(tokenId, amount);

            unchecked {
                ++i;
            }
        }

        emit TokensBatchConsumed(tokenIds, amounts);
    }

    /*//////////////////////////////////////////////////////////////
                              STATUS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates status for tokens
     * @param tokenIds Array of token IDs to update
     * @param statuses Array of new status strings
     * @dev Only callable by owner
     *      Input arrays must have the same length
     *      Status strings cannot be empty
     *      Tokens must exist
     *      Updates are performed with the current block timestamp
     */
    function update(uint256[] calldata tokenIds, string[] calldata statuses)
        external
        onlyOwner
    {
        if (tokenIds.length != statuses.length) revert InvalidBatchInput();

        uint256 length = tokenIds.length;
        uint40 timestamp = uint40(block.timestamp);

        for (uint256 i; i < length; ) {
            uint256 tokenId = tokenIds[i];
            string calldata status = statuses[i];

            if (bytes(status).length == 0) revert EmptyStatus();
            if (!_exists(tokenId)) revert TokenNotExists(tokenId);

            _tokenData[tokenId].provenance.push(
                Status({status: status, timestamp: timestamp})
            );

            emit StatusUpdated(tokenId, status, timestamp);

            unchecked {
                ++i;
            }
        }

        emit StatusesBatchUpdated(tokenIds, statuses, timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates token IPFS CID
     * @param tokenId Token ID to update
     * @param newCid New IPFS CID for token metadata
     * @dev Only callable by owner
     *      Token must exist
     */
    function setTokenCID(uint256 tokenId, string calldata newCid)
        external
        onlyOwner
    {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        _tokenData[tokenId].cid = newCid;
        emit TokenMetadataUpdated(tokenId, newCid);
    }

    /**
     * @notice Sets the HTTP gateway base URL for token metadata
     * @param newGateway New gateway URL (e.g., "https://example.com/metadata/")
     * @dev Only callable by owner
     *      When set, httpUri will return newGateway/tokenId.json
     */
    function setHttpGateway(string calldata newGateway) external onlyOwner {
        _httpGateway = newGateway;
        emit HttpGatewayUpdated(newGateway);
    }

    /*//////////////////////////////////////////////////////////////
                            SOULBOUND LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Override safeTransferFrom to implement soulbound functionality for consumed tokens
     * @param from Address to transfer tokens from
     * @param to Address to transfer tokens to
     * @param id Token ID to transfer
     * @param amount Amount of tokens to transfer
     * @param data Additional data with no specified format
     * @notice Consumed tokens cannot be transferred (soulbound)
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        if (_tokenData[id].consumed) revert TokenSoulbound();
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Override safeBatchTransferFrom to implement soulbound functionality for consumed tokens
     * @param from Address to transfer tokens from
     * @param to Address to transfer tokens to
     * @param ids Array of token IDs to transfer
     * @param amounts Array of amounts to transfer
     * @param data Additional data with no specified format
     * @notice Consumed tokens cannot be transferred (soulbound)
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        for (uint256 i = 0; i < ids.length; ) {
            if (_tokenData[ids[i]].consumed) revert TokenSoulbound();
            unchecked {
                ++i;
            }
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a token exists
     * @param tokenId Token ID to check
     * @return bool Whether the token exists
     * @dev Internal helper function
     *      A token exists if its ID is greater than 0 and less than or equal to the current token ID counter
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= _tokenIds.current();
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract
     * @param newImplementation Address of the new implementation
     * @notice This function is part of the UUPS upgradeable pattern
     *      Only the owner can upgrade the contract
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}