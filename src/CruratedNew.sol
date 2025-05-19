// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

/**
 * @title Crurated
 * @notice ERC1155 token with consumption tracking and event-based provenance
 * @dev Supports both fungible and non-fungible tokens with consumption mechanics
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

    string public constant NAME = "Crurated";
    string public constant SYMBOL = "CRURATED";

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct TokenData {
        string cid;        // IPFS Content Identifier
        bool consumed;     // Whether token is consumed
        bool consumable;   // Whether token can be consumed
    }

    struct ImportData {
        uint256 amount;      // Token amount
        string cid;          // IPFS Content Identifier
        bool consumable;     // Can be consumed
        bool consumed;       // Already consumed
        uint40[] timestamps; // Historical timestamps
        string[] statuses;   // Historical statuses
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    string private _httpGateway;
    mapping(uint256 => TokenData) private _tokenData;
    CountersUpgradeable.Counter private _tokenIds;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    
    error EmptyStatus();
    error ZeroMintAmount();
    error TokenSoulbound();
    error InvalidBatchInput();
    error TokenNotExists(uint256 tokenId);
    error TokenNotConsumable(uint256 tokenId);
    error TokenAlreadyConsumed(uint256 tokenId);
    error InsufficientBalance(uint256 tokenId, uint256 requested, uint256 available);
    error InvalidTimestamp();
    error AmountTooSmall();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event TokenMinted(uint256 indexed tokenId, uint256 amount, bool consumable);
    event StatusUpdated(uint256 indexed tokenId, string status, uint40 timestamp);
    event HttpGatewayUpdated(string newGateway);
    event TokenConsumed(uint256 indexed tokenId, uint256 amount);
    event TokenMetadataUpdated(uint256 indexed tokenId, string newCid);
    event TokensImported(uint256[] tokenIds);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner) external initializer {
        __ERC1155_init("ipfs://");
        __Ownable_init(owner);
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC VIEWS
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return string(abi.encodePacked(super.uri(0), _tokenData[tokenId].cid));
    }

    function httpUri(uint256 tokenId) public view returns (string memory) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (bytes(_httpGateway).length == 0) return "";
        return string(abi.encodePacked(_httpGateway, tokenId.toString(), ".json"));
    }

    function isConsumable(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return _tokenData[tokenId].consumable;
    }

    function isConsumed(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return _tokenData[tokenId].consumed;
    }

    function isFractionable(uint256 tokenId) external view returns (bool) {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        return balanceOf(owner(), tokenId) > 1;
    }

    function httpGateway() external view returns (string memory) {
        return _httpGateway;
    }

    /*//////////////////////////////////////////////////////////////
                              TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints a non-fractionable token (amount = 1)
     * @param cid IPFS CID for token metadata
     * @param consumable Whether the token can be consumed
     * @return uint256 Newly minted token ID
     */
    function mintNFT(
        string calldata cid,
        bool consumable
    ) external onlyOwner returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _mint(owner(), newTokenId, 1, "");

        _tokenData[newTokenId] = TokenData({
            cid: cid,
            consumed: false,
            consumable: consumable
        });

        emit TokenMinted(newTokenId, 1, consumable);
        emit StatusUpdated(newTokenId, "Token minted", uint40(block.timestamp));
        
        return newTokenId;
    }

    /**
     * @notice Mints a fractionable token (amount > 1)
     * @param amount Amount of tokens to mint (must be > 1)
     * @param cid IPFS CID for token metadata
     * @param consumable Whether the token can be consumed
     * @return uint256 Newly minted token ID
     */
    function mintFractionable(
        uint256 amount,
        string calldata cid,
        bool consumable
    ) external onlyOwner returns (uint256) {
        if (amount <= 1) revert AmountTooSmall();
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _mint(owner(), newTokenId, amount, "");

        _tokenData[newTokenId] = TokenData({
            cid: cid,
            consumed: false,
            consumable: consumable
        });

        emit TokenMinted(newTokenId, amount, consumable);
        emit StatusUpdated(newTokenId, "Token minted", uint40(block.timestamp));
        
        return newTokenId;
    }

    /**
     * @notice Consumes a non-fractionable token by marking it consumed
     * @param tokenId Token ID to consume
     */
    function consumeNFT(uint256 tokenId) external onlyOwner {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (!_tokenData[tokenId].consumable) revert TokenNotConsumable(tokenId);
        if (_tokenData[tokenId].consumed) revert TokenAlreadyConsumed(tokenId);
        if (balanceOf(owner(), tokenId) != 1) revert InsufficientBalance(tokenId, 1, balanceOf(owner(), tokenId));
        
        _tokenData[tokenId].consumed = true;
        
        emit TokenConsumed(tokenId, 1);
        emit StatusUpdated(tokenId, "Token consumed", uint40(block.timestamp));
    }

    /**
     * @notice Consumes a fractionable token by burning specified amount
     * @param tokenId Token ID to consume
     * @param amount Amount to consume
     */
    function consumeFractionable(uint256 tokenId, uint256 amount) external onlyOwner {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (!_tokenData[tokenId].consumable) revert TokenNotConsumable(tokenId);
        if (_tokenData[tokenId].consumed) revert TokenAlreadyConsumed(tokenId);
        
        uint256 balance = balanceOf(owner(), tokenId);
        if (amount > balance) revert InsufficientBalance(tokenId, amount, balance);
        if (balance <= 1) revert AmountTooSmall();
        
        _burn(owner(), tokenId, amount);
        
        emit TokenConsumed(tokenId, amount);
        emit StatusUpdated(tokenId, "Token partially consumed", uint40(block.timestamp));
    }

    /**
     * @notice Imports tokens with full history from another blockchain
     * @param data Array of import data structures
     * @return uint256[] Array of imported token IDs
     */
    function imports(ImportData[] calldata data) external onlyOwner returns (uint256[] memory) {
        uint256 length = data.length;
        uint256[] memory newTokenIds = new uint256[](length);
        
        for (uint256 i; i < length; ) {
            // Validate import data
            if (data[i].amount == 0) revert ZeroMintAmount();
            if (data[i].timestamps.length != data[i].statuses.length) revert InvalidBatchInput();
            
            // Create new token
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            newTokenIds[i] = newTokenId;
            
            // Mint token
            _mint(owner(), newTokenId, data[i].amount, "");
            
            // Set token data
            _tokenData[newTokenId] = TokenData({
                cid: data[i].cid,
                consumed: data[i].consumed,
                consumable: data[i].consumable
            });
            
            // Record historical provenance
            uint256 historyLength = data[i].timestamps.length;
            uint40 lastTimestamp = 0;
            
            for (uint256 j = 0; j < historyLength; ) {
                // Validate timestamps are in order
                if (j > 0 && data[i].timestamps[j] <= lastTimestamp) revert InvalidTimestamp();
                if (bytes(data[i].statuses[j]).length == 0) revert EmptyStatus();
                
                lastTimestamp = data[i].timestamps[j];
                
                // Emit historical status
                emit StatusUpdated(
                    newTokenId,
                    data[i].statuses[j],
                    data[i].timestamps[j]
                );
                
                unchecked { ++j; }
            }
            
            // Emit token creation events
            emit TokenMinted(newTokenId, data[i].amount, data[i].consumable);
            
            unchecked { ++i; }
        }
        
        emit TokensImported(newTokenIds);
        return newTokenIds;
    }

    /*//////////////////////////////////////////////////////////////
                              STATUS LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates token status
     * @param tokenId Token ID to update
     * @param status New status string
     */
    function updateStatus(uint256 tokenId, string calldata status) external onlyOwner {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (bytes(status).length == 0) revert EmptyStatus();
        
        emit StatusUpdated(tokenId, status, uint40(block.timestamp));
    }

    /**
     * @notice Records historical status with specific timestamp
     * @param tokenId Token ID to update
     * @param status Status message
     * @param timestamp Historical timestamp
     */
    function recordHistory(uint256 tokenId, string calldata status, uint40 timestamp) external onlyOwner {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        if (bytes(status).length == 0) revert EmptyStatus();
        
        emit StatusUpdated(tokenId, status, timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates token metadata CID
     * @param tokenId Token ID to update
     * @param newCid New IPFS CID
     */
    function setTokenCID(uint256 tokenId, string calldata newCid) external onlyOwner {
        if (!_exists(tokenId)) revert TokenNotExists(tokenId);
        _tokenData[tokenId].cid = newCid;
        
        emit TokenMetadataUpdated(tokenId, newCid);
        emit StatusUpdated(tokenId, "Metadata updated", uint40(block.timestamp));
    }

    /**
     * @notice Sets HTTP gateway for metadata
     * @param newGateway New gateway URL
     */
    function setHttpGateway(string calldata newGateway) external onlyOwner {
        _httpGateway = newGateway;
        emit HttpGatewayUpdated(newGateway);
    }

    /*//////////////////////////////////////////////////////////////
                            SOULBOUND LOGIC
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        if (_tokenData[id].consumed) revert TokenSoulbound();
        super.safeTransferFrom(from, to, id, amount, data);
        
        emit StatusUpdated(
            id,
            "Token transferred",
            uint40(block.timestamp)
        );
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; ) {
            if (_tokenData[ids[i]].consumed) revert TokenSoulbound();
            unchecked { ++i; }
        }
        
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
        
        uint40 timestamp = uint40(block.timestamp);
        for (uint256 i = 0; i < length; ) {
            emit StatusUpdated(ids[i], "Token transferred", timestamp);
            unchecked { ++i; }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= _tokenIds.current();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}