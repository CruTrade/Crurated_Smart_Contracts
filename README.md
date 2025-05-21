# Crurated Smart Contract System

![Crurated](https://crurated.com/logo.png)

## Overview

Crurated is a premium ERC1155 token implementation designed for collectibles with provenance tracking. The contract offers a sophisticated solution for tracking the authenticity and history of digital assets through blockchain technology.

## Key Features

- **Soulbound Tokens**: Non-transferable tokens permanently attached to their original owner
- **IPFS-Native Metadata**: Efficient and decentralized storage for token metadata
- **Provenance Tracking**: Comprehensive historical tracking with timestamped status records
- **Batch Operations**: Gas-optimized batch functions for all major operations
- **Upgradeable Architecture**: UUPS pattern for future improvements
- **Emergency Pause**: Protocol-level pause functionality for risk mitigation

## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) - for development and testing
- [Node.js](https://nodejs.org/) v16+ - for running scripts
- [Git](https://git-scm.com/) - for version control

### Complete Installation (Step-by-Step)

1. **Install Foundry**:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/your-org/crurated.git
   cd crurated
   ```

3. **Install OpenZeppelin contracts and dependencies**:
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.1
   forge install OpenZeppelin/openzeppelin-contracts@v5.0.1
   forge install foundry-rs/forge-std
   ```

4. **Install Node.js dependencies** (if any package.json exists):
   ```bash
   npm install
   ```

5. **Compile contracts**:
   ```bash
   forge build
   ```

6. **Run tests**:
   ```bash
   forge test
   ```

## Project Structure

```
crurated/
├── src/
│   ├── Crurated.sol                   # Main contract implementation
│   └── abstracts/
│       └── CruratedBase.sol           # Abstract base contract
├── test/
│   └── Crurated.t.sol                 # Test suite
├── script/
│   └── Deploy.s.sol                   # Deployment script (if included)
├── lib/                               # Dependencies (managed by Forge)
├── foundry.toml                       # Foundry configuration
└── README.md                          # Project documentation
```

## Contract Architecture

The contract architecture follows a modular approach:

```
Crurated (Main Implementation)
↑
CruratedBase (Abstract Foundation)
↑
ERC1155Upgradeable + OwnableUpgradeable + PausableUpgradeable + UUPSUpgradeable
```

### CruratedBase.sol

Abstract foundation providing core functionality:
- IPFS URI handling
- Status tracking infrastructure
- Core data structures and events

### Crurated.sol

Main implementation with business logic:
- Soulbound token mechanism
- Minting and migration functions
- Status update operations
- Metadata management

## Contract Flows

### Token Creation

1. **Mint**: Create new tokens with metadata
   ```solidity
   // Example: Minting a single token
   string[] memory cids = new string[](1);
   cids[0] = "QmExampleCID";
   uint256[] memory amounts = new uint256[](1);
   amounts[0] = 1;
   crurated.mint(cids, amounts);
   ```

2. **Migration**: Import tokens with historical data
   ```solidity
   // Example: Migrating a token with history
   CruratedBase.Data[] memory data = new CruratedBase.Data[](1);
   data[0] = CruratedBase.Data({
       cid: "QmExampleCID",
       amount: 1,
       statuses: ["Created", "Verified"],
       timestamps: [uint40(1000000), uint40(1100000)]
   });
   crurated.migrate(data);
   ```

### Status Updates

1. **Current Status Update**:
   ```solidity
   // Example: Update status with current timestamp
   uint256[] memory tokenIds = new uint256[](1);
   tokenIds[0] = 1;
   string[] memory statuses = new string[](1);
   statuses[0] = "Certified";
   crurated.updateCurrentStatus(tokenIds, statuses);
   ```

2. **Historical Status Update**:
   ```solidity
   // Example: Add historical status
   uint256[] memory tokenIds = new uint256[](1);
   tokenIds[0] = 1;
   string[] memory statuses = new string[](1);
   statuses[0] = "Historical Event";
   uint40[] memory timestamps = new uint40[](1);
   timestamps[0] = 1000000;
   crurated.updateHistoricalStatus(tokenIds, statuses, timestamps);
   ```

## Testing Framework

The project includes a comprehensive test suite in `Crurated.t.sol`.

### Running Tests

```bash
# Basic test run
forge test

# Verbose output with stack traces
forge test -vvv

# Gas report
forge test --gas-report

# Run specific tests
forge test --match-function testMintSingleToken

# Test coverage
forge coverage
```

### Test Coverage Areas

The test suite covers:
- Initialization and setup
- Token minting and validation
- Migration with historical data
- Status update functionality
- Metadata management
- Soulbound mechanism (transfer restrictions)
- Pause functionality
- Contract upgrade security
- Gas optimization

## Deployment Process

The deployment process involves two steps:

1. **Deploy Implementation**:
   ```bash
   # Example using Forge script (if Deploy.s.sol exists)
   forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
   ```

   Or manually:
   ```solidity
   // Manual deployment example
   Crurated implementation = new Crurated();
   bytes memory initData = abi.encodeWithSelector(Crurated.initialize.selector, owner);
   ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
   Crurated crurated = Crurated(address(proxy));
   ```

2. **Post-Deployment Configuration**:
   ```solidity
   // Set HTTP gateway (optional)
   crurated.setHttpGateway("https://example.com/metadata/");
   ```

## Security Considerations

### Key Security Features

1. **Soulbound Mechanism**: Tokens cannot be transferred after minting
2. **Admin Controls**: Only owner can mint and update token data
3. **Pause Functionality**: Contract can be paused in emergency
4. **Upgrade Security**: UUPS pattern with owner-only upgrades

### Gas Optimization

The contract uses several gas optimization techniques:
- Batch operations for all major functions
- Unchecked increments in loops where overflow is impossible
- Custom errors instead of revert strings
- Event-based history tracking to avoid excessive storage costs

## API Reference

### Core Functions

#### Token Management

- `mint(string[] calldata cids, uint256[] calldata amounts)`: Mints new tokens
- `migrate(Data[] calldata data)`: Imports tokens with historical data

#### Status Updates

- `updateCurrentStatus(uint256[] calldata tokenIds, string[] calldata statuses)`: Updates token status with current timestamp
- `updateHistoricalStatus(uint256[] calldata tokenIds, string[] calldata statuses, uint40[] calldata timestamps)`: Updates token status with historical timestamps

#### Metadata Management

- `setCIDs(uint256[] calldata tokenIds, string[] calldata newCids)`: Updates token metadata
- `setHttpGateway(string calldata newGateway)`: Sets HTTP gateway for metadata access

#### Admin Controls

- `pause()`: Pauses contract operations
- `unpause()`: Resumes contract operations

### View Functions

- `uri(uint256 tokenId)`: Gets token's IPFS URI
- `httpUri(uint256 tokenId)`: Gets token's HTTP URI
- `cidOf(uint256 tokenId)`: Gets token's IPFS CID
- `tokenCount()`: Gets total token count

## Troubleshooting

### Common Issues

1. **Dependency Installation Failures**:
   ```bash
   # Retry with specific version
   forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.1 --no-commit
   ```

2. **Compilation Errors**:
   ```bash
   # Clean cache and rebuild
   forge clean
   forge build
   ```

3. **Test Failures**:
   ```bash
   # Run with maximum verbosity
   forge test -vvvv
   ```

## Contributing

Please follow these guidelines for contributing:
1. Fork the repository
2. Create a feature branch
3. Commit changes with clear messages
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

- Security Contact: security@crurated.com
- Author: [mazzacash](https://linkedin.com/in/mazzacash/)
- Website: [https://crurated.com/](https://crurated.com/)
