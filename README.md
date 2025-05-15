# Crurated Technical Documentation

## Overview

The Crurated smart contract is an implementation of the ERC1155 multi-token standard with enhanced consumption mechanics and provenance tracking. It is designed to support digital assets that can be consumed, partially consumed (fractionable), and have a detailed history of status updates.

This document provides a technical overview of the smart contract architecture and its test suite to support the audit process.

## Contract Architecture

### Core Functionality

The Crurated contract extends the ERC1155 standard with the following key features:

1. **Fractionable Tokens**: Tokens can be partially consumed when their quantity is greater than 1.
2. **Consumption Mechanics**: Tokens can be marked as consumable or non-consumable. Consumable tokens may be burned if fractionable, or marked as consumed otherwise.
3. **Soulbound Functionality**: Consumed tokens become non-transferable (soulbound).
4. **Provenance Tracking**: Each token maintains a chronological history of status updates.
5. **Dual Metadata Support**: Tokens reference metadata via both IPFS and HTTP gateways.
6. **Upgradeability**: The contract follows the UUPS pattern for future upgrades.

### Inheritance Structure

```
ERC1155Upgradeable
       ↑
OwnableUpgradeable    UUPSUpgradeable
       ↑                    ↑
             Crurated
```

### Key Data Structures

#### Status

```solidity
struct Status {
    string status;   // Status description
    uint40 timestamp; // Timestamp of update
}
```

The `Status` struct stores each status update with a description and timestamp.

#### Data

```solidity
struct Data {
    string cid;       // IPFS CID for token metadata
    bool consumed;    // Whether the token has been consumed
    bool consumable;  // Whether the token can be consumed
    bool fractionable; // Whether the token can be partially consumed (quantity > 1)
    Status[] provenance; // Complete provenance history
}
```

The `Data` struct stores all token-specific information including its metadata reference, consumption state, and complete provenance history.

### State Variables

- `_httpGateway`: HTTP gateway base URL for redirecting to IPFS content
- `_tokenData`: Mapping from token ID to token data
- `_tokenIds`: Counter for generating sequential token IDs

### Functional Modules

#### Token Management

- `mint()`: Creates new tokens with specified quantities and properties
- `consume()`: Consumes tokens - burns if fractionable, marks as consumed otherwise

#### Status Management

- `update()`: Adds new status entries to tokens' provenance history
- `getCurrentStatus()`: Returns the most recent status of a token
- `getProvenance()`: Returns the complete status history of a token

#### Metadata Management

- `setTokenCID()`: Updates the IPFS Content Identifier for a token
- `setHttpGateway()`: Sets the base HTTP gateway URL for metadata access
- `uri()`: Returns the IPFS URI for a token
- `httpUri()`: Returns the HTTP URI for a token

#### Soulbound Functionality

- Overridden `safeTransferFrom()` and `safeBatchTransferFrom()`: Prevents transfers of consumed tokens

#### Upgradeability

- `_authorizeUpgrade()`: Restricts upgrade capability to the contract owner

## Security Considerations

### Access Control

The contract uses OpenZeppelin's `OwnableUpgradeable` for access control. All administrative functions (minting, consuming, updating status, setting metadata) are restricted to the contract owner.

### Error Handling

The contract uses custom error types with descriptive messages instead of revert strings, providing better error diagnostics while reducing gas costs.

### Event Emission

Every state-changing operation emits corresponding events to facilitate off-chain tracking and indexing.

### Input Validation

Input parameters are validated before processing:
- Token existence is checked in all token-specific operations
- Empty status strings are rejected
- Zero mint amounts are rejected
- Insufficient balances for consumption are checked

### Upgradeability Security

The contract follows the UUPS (Universal Upgradeable Proxy Standard) pattern with proper authorization checks in place.

## Test Suite Documentation

The test suite for the Crurated contract follows best practices for comprehensive testing of smart contracts, ensuring all functionality works as expected and edge cases are properly handled.

### Test Structure

Tests are organized into logical groups testing specific aspects of the contract:

1. **Deployment Tests**
   - Verify correct initialization
   - Check owner settings
   - Validate initial state variables

2. **Minting Tests**
   - Mint single tokens
   - Batch mint multiple tokens
   - Test fractionable flag setting
   - Verify ownership of minted tokens
   - Test error conditions (zero amount, unauthorized minting)

3. **Consumption Tests**
   - Test consuming non-fractionable tokens
   - Test partially consuming fractionable tokens
   - Verify proper state changes after consumption
   - Test error conditions (consuming non-consumable, already consumed, insufficient balance)

4. **Status Update Tests**
   - Add status updates to tokens
   - Verify provenance history accuracy
   - Test batch updates
   - Validate timestamp recording
   - Test error conditions (empty status, non-existent tokens)

5. **Metadata Tests**
   - Test setting and updating CIDs
   - Verify proper URI construction
   - Test HTTP gateway functionality
   - Validate error conditions

6. **Soulbound Tests**
   - Verify transfers are blocked for consumed tokens
   - Test successful transfers for non-consumed tokens
   - Test batch transfer behavior with mixed token states

7. **Upgradeability Tests**
   - Test contract upgradeability
   - Verify state preservation after upgrades
   - Test unauthorized upgrade attempts

### Test Coverage

The test suite aims for 100% coverage of:
- Functions
- Code branches
- Error conditions
- Event emissions

### Test Utilities

The test framework includes several utilities:
- Deployment helpers
- Token creation helpers
- Status update helpers
- Error assertion helpers

### Gas Optimization Tests

Specific tests measure gas consumption for critical operations to ensure efficiency:
- Minting operations
- Consumption operations
- Status updates
- Transfers

## Integration Considerations

### Front-end Integration

The contract supports both IPFS and HTTP URIs for metadata, facilitating integration with various front-end applications. The `httpUri()` function returns user-friendly URLs that can be directly accessed in web browsers.

### Indexing and Analytics

All significant state changes emit events that can be indexed by off-chain services:
- `TokenMinted` / `TokensBatchMinted`
- `StatusUpdated` / `StatusesBatchUpdated`
- `TokenConsumed` / `TokensBatchConsumed`
- `TokenMetadataUpdated`
- `HttpGatewayUpdated`

### Integration with External Systems

The contract's metadata system is designed to work with IPFS, allowing for decentralized storage of token metadata. The addition of HTTP gateway support enables easier integration with traditional web services.

## Deployment Procedure

1. Deploy implementation contract
2. Deploy proxy contract pointing to implementation
3. Call `initialize(owner)` on the proxy contract
4. Set HTTP gateway if needed with `setHttpGateway()`
5. Begin minting tokens with `mint()`

## Known Limitations

- The contract doesn't implement explicit batch size limits, relying on block gas limits
- Status strings have no length limits
- CIDs are not validated for format correctness

## Conclusion

The Crurated smart contract provides a robust and feature-rich implementation of the ERC1155 standard with enhanced consumption mechanics and detailed provenance tracking. Its well-structured architecture, comprehensive error handling, and thorough documentation make it suitable for production deployment after audit verification.