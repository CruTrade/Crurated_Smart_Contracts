// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @title CruratedBase
 * @author mazzacash (https://www.linkedin.com/in/mazzacash/)
 * @notice Abstract base for soulbound ERC1155 collectibles with provenance tracking
 * @dev Gas-optimized implementation with batch operations and upgradeable architecture.
 *      Features comprehensive status tracking, metadata management, and historical migration.
 *      All tokens are soulbound (non-transferable) to prevent secondary market speculation.
 */
abstract contract CruratedBase is
    ERC1155Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Human-readable collection name
    string public constant name = "Crurated";
    
    /// @notice Collection symbol identifier
    string public constant symbol = "CRURATED";

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @dev Next available status identifier
    uint256 internal _nextStatusId;

    /// @dev Sequential token identifier counter
    CountersUpgradeable.Counter internal _tokenIds;

    /// @dev Token metadata mapping: tokenId => IPFS CID
    mapping(uint256 => string) internal _cids;

    /// @dev Status registry mapping: statusId => human readable name
    mapping(uint256 => string) internal _statusNames;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Provenance record structure for collectible lifecycle tracking
     * @param statusId Unique identifier for provenance type
     * @param timestamp Precise moment of provenance event (unix timestamp)
     * @param reason Detailed explanation of provenance change
     */
    struct Status {
        uint256 statusId;
        uint256 timestamp;
        string reason;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when collectible provenance is updated
     * @param tokenId Collectible receiving provenance update
     * @param statusId Provenance type for efficient filtering
     * @param timestamp Precise moment of provenance event
     * @param reason Detailed explanation of provenance change
     */
    event ProvenanceUpdated(
        uint256 indexed tokenId,
        uint256 indexed statusId,
        uint256 timestamp,
        string reason
    );

    /**
     * @notice Emitted when new provenance type is registered
     * @param statusId Unique identifier assigned to provenance type
     * @param name Human-readable provenance type name
     */
    event ProvenanceTypeAdded(uint256 indexed statusId, string name);

    /**
     * @notice Emitted when collectible metadata is updated
     * @param tokenId Collectible with updated metadata
     * @param cid New IPFS content identifier
     */
    event MetadataUpdated(uint256 indexed tokenId, string cid);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when creating provenance type with empty name
    error EmptyStatus();
    
    /// @notice Thrown when invalid parameters provided
    error InvalidInput();
    
    /// @notice Thrown when attempting transfer of soulbound token
    error TokenSoulbound();
    
    /// @notice Thrown when attempting zero-quantity mint
    error ZeroMintAmount();
    
    /// @notice Thrown when batch operation arrays have mismatched lengths
    error InvalidBatchInput();
    
    /// @notice Thrown when referencing non-existent token
    error TokenNotExists(uint256 tokenId);
    
    /// @notice Thrown when referencing non-existent provenance type
    error StatusNotExists(uint256 statusId);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates token existence before operation
     * @param tokenId Token identifier to validate
     */
    modifier tokenExists(uint256 tokenId) {
        if (tokenId == 0 || tokenId > _tokenIds.current())
            revert TokenNotExists(tokenId);
        _;
    }

    /**
     * @dev Validates provenance type existence before operation
     * @param statusId Provenance type identifier to validate
     */
    modifier statusExists(uint256 statusId) {
        if (bytes(_statusNames[statusId]).length == 0)
            revert StatusNotExists(statusId);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Initializes upgradeable contract with essential dependencies
     * @param owner Address receiving administrative privileges
     */
    function __CruratedBase_init(address owner) internal onlyInitializing {
        __ERC1155_init("ipfs://");
        __Ownable_init(owner);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns complete metadata URI for specified collectible
     * @param tokenId Collectible identifier
     * @return Complete IPFS URI for metadata access
     */
    function uri(uint256 tokenId) public view override tokenExists(tokenId) returns (string memory) {
        return string(abi.encodePacked(super.uri(0), _cids[tokenId]));
    }

    /**
     * @notice Returns total number of collectibles created
     * @return Current collectible count
     */
    function tokenCount() public view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @notice Returns IPFS content identifier for specified collectible
     * @param tokenId Collectible identifier
     * @return IPFS content identifier
     */
    function cidOf(uint256 tokenId) public view tokenExists(tokenId) returns (string memory) {
        return _cids[tokenId];
    }

    /**
     * @notice Returns human-readable name for provenance type
     * @param statusId Provenance type identifier
     * @return Human-readable provenance type name
     */
    function statusName(uint256 statusId) public view statusExists(statusId) returns (string memory) {
        return _statusNames[statusId];
    }

    /**
     * @notice Returns next available provenance type identifier
     * @return Next provenance type identifier
     */
    function nextStatusId() public view returns (uint256) {
        return _nextStatusId + 1;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Creates new collectible with metadata
     * @param cid IPFS content identifier for metadata
     * @return tokenId Newly created collectible identifier
     */
    function _createToken(string calldata cid) internal returns (uint256 tokenId) {
        if (bytes(cid).length == 0) revert InvalidInput();

        _tokenIds.increment();
        tokenId = _tokenIds.current();
        _cids[tokenId] = cid;

        return tokenId;
    }

    /**
     * @dev Updates metadata for existing collectible
     * @param tokenId Collectible to update
     * @param newCid New IPFS content identifier
     */
    function _updateMetadata(uint256 tokenId, string calldata newCid) internal tokenExists(tokenId) {
        if (bytes(newCid).length == 0) revert InvalidInput();

        _cids[tokenId] = newCid;
        emit MetadataUpdated(tokenId, newCid);
    }

    /**
     * @dev Registers new provenance type with human-readable name
     * @param _name Human-readable provenance type name (FIXED: using parameter instead of constant)
     * @return statusId Assigned provenance type identifier
     */
    function _registerStatus(string calldata _name) internal returns (uint256 statusId) {
        if (bytes(_name).length == 0) revert EmptyStatus();

        statusId = ++_nextStatusId;
        _statusNames[statusId] = _name; // FIXED: using _name parameter instead of constant name

        emit ProvenanceTypeAdded(statusId, _name);
        return statusId;
    }

    /**
     * @dev Records provenance update for collectible
     * @param tokenId Collectible receiving update
     * @param statusId Provenance type identifier
     * @param reason Detailed explanation of change
     * @param timestamp Precise moment of provenance event
     */
    function _addStatus(
        uint256 tokenId,
        uint256 statusId,
        string calldata reason,
        uint256 timestamp
    ) internal tokenExists(tokenId) statusExists(statusId) {
        emit ProvenanceUpdated(tokenId, statusId, timestamp, reason);
    }

    /**
     * @dev Processes standard mint operation with validation
     * @param cid IPFS content identifier
     * @param amount Quantity to mint
     * @return tokenId New collectible identifier
     * @return mintAmount Validated mint quantity
     */
    function _processMint(
        string calldata cid,
        uint256 amount
    ) internal returns (uint256 tokenId, uint256 mintAmount) {
        if (amount == 0) revert ZeroMintAmount();

        tokenId = _createToken(cid);
        return (tokenId, amount);
    }

    /**
     * @dev Processes migration with complete historical provenance reconstruction
     * @param cid IPFS content identifier
     * @param amount Quantity to mint
     * @param statuses Complete historical provenance timeline
     * @return tokenId New collectible identifier
     * @return mintAmount Validated mint quantity
     */
    function _processMigration(
        string calldata cid,
        uint256 amount,
        Status[] calldata statuses
    ) internal returns (uint256 tokenId, uint256 mintAmount) {
        if (amount == 0) revert ZeroMintAmount();

        tokenId = _createToken(cid);

        // Reconstruct complete historical provenance timeline
        uint256 statusLength = statuses.length;
        for (uint256 j; j < statusLength;) {
            Status calldata status = statuses[j];
            _addStatus(tokenId, status.statusId, status.reason, status.timestamp);
            unchecked { ++j; }
        }

        return (tokenId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                UUPS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Authorizes contract upgrades with strict owner validation
     * @param newImplementation Address of new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}