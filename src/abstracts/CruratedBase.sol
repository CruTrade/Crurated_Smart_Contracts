// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

/**
 * @title CruratedBase (https://crurated.com/)
 * @author mazzacash (https://www.linkedin.com/in/mazzacash/)
 * @notice Abstract foundation for the Crurated protocol's token system
 * @dev A sophisticated base contract providing core functionality for NFT collectibles
 *      with built-in provenance tracking and non-transferability.
 *
 *      Key features include:
 *      - Soulbound tokens (non-transferable after minting)
 *      - IPFS-native metadata with optimized URI handling
 *      - Comprehensive historical provenance tracking
 *      - Emergency pause functionality for risk mitigation
 *      - Secure upgrade mechanisms via UUPS pattern
 *
 *      This contract is designed as an abstract base to facilitate future extensions
 *      while maintaining a clean separation of concerns.
 */
abstract contract CruratedBase is
    ERC1155Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Name of the token collection
    string public constant name = "Crurated";

    /// @notice Symbol of the token collection
    string public constant symbol = "CRURATED";

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev HTTP gateway prefix for metadata (for traditional web access)
    string internal _httpGateway;

    /// @dev Mapping from token ID to IPFS CID
    mapping(uint256 => string) internal _cids;

    /// @dev Token ID counter for sequential minting
    CountersUpgradeable.Counter internal _tokenIds;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Structure for token data during migration
     * @param cid IPFS Content Identifier for token metadata
     * @param amount Token supply amount
     * @param statuses Historical status records
     * @param timestamps Timestamps corresponding to historical statuses
     */
    struct Data {
        string cid;
        uint256 amount;
        string[] statuses;
        uint40[] timestamps;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a status string is empty
    error EmptyStatus();

    /// @notice Thrown when input validation fails
    error InvalidInput();

    /// @notice Thrown when attempting to transfer a non-transferable token
    error TokenSoulbound();    

    /// @notice Thrown when a mint amount is zero
    error ZeroMintAmount();

    /// @notice Thrown when batch input arrays have mismatched lengths
    error InvalidBatchInput();

    /// @notice Thrown when referenced token does not exist
    error TokenNotExists(uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates that a token exists
     * @param tokenId Token ID to validate
     */
    modifier tokenExists(uint256 tokenId) {
        if (tokenId == 0 || tokenId > _tokenIds.current())
            revert TokenNotExists(tokenId);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a token's status is updated
     * @param tokenId ID of the token
     * @param status New status message
     * @param timestamp Time when status was recorded
     */
    event StatusUpdated(
        uint256 indexed tokenId,
        string status,
        uint40 timestamp
    );

    /**
     * @notice Emitted when HTTP gateway is updated
     * @param newGateway New gateway URL
     */
    event HttpGatewayUpdated(string newGateway);

    /**
     * @notice Emitted when token metadata is updated
     * @param tokenId ID of the token
     * @param cid New IPFS CID
     */
    event MetadataUpdated(uint256 indexed tokenId, string cid);

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initialization function for the base contract
     * @param owner Address that will own the contract
     */
    function __CruratedBase_init(address owner) internal onlyInitializing {
        // Initialize with ipfs:// as the base URI prefix
        __ERC1155_init("ipfs://");
        __Ownable_init(owner);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                              CORE VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the complete metadata URI for a token
     * @dev Overrides the standard uri function to return the CID for specific token
     * @param tokenId Token identifier
     * @return string Token's metadata URI, using the base URI from ERC1155
     */
    function uri(uint256 tokenId)
        public
        view
        override
        tokenExists(tokenId)
        returns (string memory)
    {
        // Get the base URI from parent contract and append this token's CID
        return string(abi.encodePacked(super.uri(0), _cids[tokenId]));
    }

    /**
     * @notice Gets the HTTP URI for a token (for traditional web access)
     * @dev Constructs a web-accessible URL using the HTTP gateway and token ID
     * @param tokenId Token identifier
     * @return string Token's HTTP URI
     */
    function httpUri(uint256 tokenId)
        public
        view
        tokenExists(tokenId)
        returns (string memory)
    {
        if (bytes(_httpGateway).length == 0) return "";
        return
            string(abi.encodePacked(_httpGateway, tokenId.toString(), ".json"));
    }

    /**
     * @notice Gets the current HTTP gateway URL
     * @return string The HTTP gateway URL
     */
    function httpGateway() public view returns (string memory) {
        return _httpGateway;
    }

    /**
     * @notice Gets the current total token count
     * @return uint256 Current number of token IDs created
     */
    function tokenCount() public view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @notice Gets a token's IPFS CID directly
     * @param tokenId Token identifier
     * @return string Token's IPFS CID
     */
    function cidOf(uint256 tokenId)
        public
        view
        tokenExists(tokenId)
        returns (string memory)
    {
        return _cids[tokenId];
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Update metadata for a single token
     * @param tokenId Token ID
     * @param newCid New IPFS CID
     */
    function _updateMetadata(uint256 tokenId, string calldata newCid)
        internal
        tokenExists(tokenId)
    {
        // Validate CID
        if (bytes(newCid).length == 0) revert InvalidInput();

        // Update metadata
        _cids[tokenId] = newCid;

        // Emit metadata event
        emit MetadataUpdated(tokenId, newCid);
    }

    /**
     * @dev Add a status update for a token
     * @param tokenId Token ID
     * @param status Status message
     * @param timestamp Status timestamp
     */
    function _addStatus(
        uint256 tokenId,
        string memory status,
        uint40 timestamp
    ) internal tokenExists(tokenId) {
        // Validate status
        if (bytes(status).length == 0) revert EmptyStatus();

        // Emit status event
        emit StatusUpdated(tokenId, status, timestamp);
    }

    /**
     * @dev Create a new token and assign metadata
     * @param cid IPFS CID for token metadata
     * @return tokenId The new token ID
     */
    function _createToken(string calldata cid)
        internal
        returns (uint256 tokenId)
    {
        if (bytes(cid).length == 0) revert InvalidInput();

        // Create new token ID
        _tokenIds.increment();
        tokenId = _tokenIds.current();

        // Set token metadata
        _cids[tokenId] = cid;
        
        // Emit metadata created event
        emit MetadataUpdated(tokenId, cid);

        return tokenId;
    }

    /**
     * @dev UUPS authorization function for upgrades
     * @param newImplementation Address of new implementation
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}