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
 * @notice Enterprise-grade abstract contract for soulbound NFT collectibles with comprehensive provenance tracking
 * @dev Advanced implementation featuring O(1) lookups, gas-optimized batch operations, and atomic data migration capabilities.
 *      Designed for high-performance collectible management with immutable ownership and complete audit trails.
 *
 *      Key Features:
 *      • Soulbound architecture preventing secondary market speculation
 *      • Dynamic provenance system with efficient reverse lookups
 *      • Atomic migration supporting complete historical reconstruction
 *      • UUPS upgradeability with strict owner authorization
 *      • Production-ready security with comprehensive input validation
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
    uint8 internal _nextStatusId;

    /// @dev Sequential token identifier counter
    CountersUpgradeable.Counter internal _tokenIds;

    /// @dev Token metadata mapping: tokenId => IPFS CID
    mapping(uint256 => string) internal _cids;

    /// @dev Provenance type registry: statusId => human readable name
    mapping(uint8 => string) internal _statusNames;

    /// @dev Reverse lookup optimization: keccak256(name) => statusId
    mapping(bytes32 => uint8) internal _statusNameToId;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Provenance record structure for collectible lifecycle tracking
     * @param statusId Unique identifier for provenance type
     * @param timestamp Precise moment of provenance event
     * @param reason Detailed explanation of provenance change
     */
    struct Status {
        uint8 statusId;
        uint40 timestamp;
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
        uint8 indexed statusId,
        uint40 timestamp,
        string reason
    );

    /**
     * @notice Emitted when new provenance type is registered
     * @param statusId Unique identifier assigned to provenance type
     * @param name Human-readable provenance type name
     */
    event ProvenanceTypeAdded(uint8 indexed statusId, string name);

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
    error StatusNotExists(uint8 statusId);

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
    modifier statusExists(uint8 statusId) {
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
    function uri(
        uint256 tokenId
    ) public view override tokenExists(tokenId) returns (string memory) {
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
    function cidOf(
        uint256 tokenId
    ) public view tokenExists(tokenId) returns (string memory) {
        return _cids[tokenId];
    }

    /**
     * @notice Returns human-readable name for provenance type
     * @param statusId Provenance type identifier
     * @return Human-readable provenance type name
     */
    function statusName(
        uint8 statusId
    ) public view statusExists(statusId) returns (string memory) {
        return _statusNames[statusId];
    }

    /**
     * @notice Returns next available provenance type identifier
     * @return Next provenance type identifier
     */
    function nextStatusId() public view returns (uint8) {
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
    function _createToken(
        string calldata cid
    ) internal returns (uint256 tokenId) {
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
    function _updateMetadata(
        uint256 tokenId,
        string calldata newCid
    ) internal tokenExists(tokenId) {
        if (bytes(newCid).length == 0) revert InvalidInput();

        _cids[tokenId] = newCid;
        emit MetadataUpdated(tokenId, newCid);
    }

    /**
     * @dev Registers new provenance type with O(1) lookup optimization
     * @param _name Human-readable provenance type name
     * @return statusId Assigned provenance type identifier
     */
    function _registerStatus(
        string calldata _name
    ) internal returns (uint8 statusId) {
        if (bytes(name).length == 0) revert EmptyStatus();

        bytes32 nameHash = keccak256(bytes(_name));

        // Return existing identifier if already registered
        if (_statusNameToId[nameHash] != 0) {
            return _statusNameToId[nameHash];
        }

        statusId = ++_nextStatusId;
        _statusNames[statusId] = name;
        _statusNameToId[nameHash] = statusId;

        emit ProvenanceTypeAdded(statusId, name);
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
        uint8 statusId,
        string calldata reason,
        uint40 timestamp
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
        for (uint256 j; j < statusLength; ) {
            Status calldata status = statuses[j];
            _addStatus(
                tokenId,
                status.statusId,
                status.reason,
                status.timestamp
            );
            unchecked {
                ++j;
            }
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
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
