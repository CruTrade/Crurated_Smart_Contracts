# Crurated Smart Contract System

## Overview

Crurated is a premium ERC1155 token implementation designed for collectibles with provenance tracking. The contract offers a sophisticated solution for tracking the authenticity and history of digital assets through blockchain technology.

## Key Features

- **Soulbound Tokens**: Non-transferable tokens permanently attached to their original owner
- **IPFS-Native Metadata**: Efficient and decentralized storage for token metadata
- **Provenance Tracking**: Comprehensive historical tracking with timestamped status records
- **Batch Operations**: Gas-optimized batch functions for all major operations
- **Upgradeable Architecture**: UUPS pattern for future improvements
- **Emergency Pause**: Protocol-level pause functionality for risk mitigation

## Prerequisites

- [Foundry](https://getfoundry.sh/) - for development and testing
- [Git](https://git-scm.com/) - for version control

## Getting Started

### Installation

1. **Install Foundry**:

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone and setup**:

   ```bash
   git clone git@github.com:CruTrade/Crurated_Smart_Contracts.git
   cd Crurated_Smart_Contracts
   forge soldeer install
   forge build
   forge test
   ```

## Project Structure

```text
Crurated_Smart_Contracts/
├── src/
│   ├── Crurated.sol                   # Main contract implementation
│   └── abstracts/
│       └── CruratedBase.sol           # Abstract base contract
├── test/
│   └── Crurated.t.sol                 # Test suite
├── script/
│   └── Deploy.s.sol                   # Deployment script
├── dependencies/                      # Dependencies (managed by Soldeer)
├── foundry.toml                       # Foundry configuration
├── soldeer.lock                       # Soldeer lock file
└── README.md                          # Project documentation
```

## Quick Commands

```bash
# Build contracts
forge build

# Run tests
forge test

# Format code
forge fmt

# Generate gas snapshots
forge snapshot

# Start local Anvil node
anvil

# Deploy locally (no setup required)
./deploy.sh local
```

## Contract Architecture

```
Crurated (Main Implementation)
↑
CruratedBase (Abstract Foundation)
↑
ERC1155Upgradeable + OwnableUpgradeable + PausableUpgradeable + UUPSUpgradeable
```

### CruratedBase.sol

Abstract foundation providing core functionality:

- `mint(string[] calldata cids, uint256[] calldata amounts)`: Mints new tokens
- `migrate(Data[] calldata data)`: Imports tokens with historical data

#### Status Updates

- `updateCurrentStatus(uint256[] calldata tokenIds, string[] calldata statuses)`: Updates token status with current timestamp
- `updateHistoricalStatus(uint256[] calldata tokenIds, string[] calldata statuses, uint40[] calldata timestamps)`: Updates token status with historical timestamps

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

## Deployment

### Environment Setup

Create a `.env` file:

```bash
# Required for mainnet/testnet deployments
PRIVATE_KEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
OWNER=0x1234567890123456789012345678901234567890

# Required for mainnet/testnet deployments
AVALANCHE_MAINNET_RPC=https://api.avax.network/ext/bc/C/rpc
AVALANCHE_FUJI_RPC=https://api.avax-test.network/ext/bc/C/rpc

# Optional: Gas settings
GAS_LIMIT=5000000
GAS_PRICE=20000000000  # 20 gwei

# Optional: Deployment settings
NETWORK=testnet  # local, testnet, or mainnet
```

### Deployment Options

#### Local Development (No Setup Required)

```bash
./deploy.sh local
```

#### Testnet/Mainnet

```bash
./deploy.sh testnet
./deploy.sh mainnet
```

### Manual Deployment

```bash
# Local
forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --broadcast --verify --sig "runLocal()"

# Testnet
forge script script/Deploy.s.sol:Deploy --rpc-url $AVALANCHE_FUJI_RPC --broadcast --verify --sig "runTestnet()"

# Mainnet
forge script script/Deploy.s.sol:Deploy --rpc-url $AVALANCHE_MAINNET_RPC --broadcast --verify --sig "runMainnet()"
```

### Contract Architecture

The deployment creates two contracts:

1. **Implementation Contract**: Contains the actual contract logic
2. **Proxy Contract**: Points to the implementation and stores state

This UUPS (Universal Upgradeable Proxy Standard) pattern allows for:

- Gas-efficient upgrades
- State preservation during upgrades
- Separation of logic and storage

### Verification

After deployment, verify your contract:

```bash
./deploy.sh verify <PROXY_ADDRESS> <RPC_URL>
```

Example:

```bash
./deploy.sh verify 0x1234... http://localhost:8545
```

### Post-Deployment

After successful deployment, you can:

1. **Add Status Types**: Register new provenance status types

   ```solidity
   crurated.addStatus("Authenticated");
   crurated.addStatus("Verified");
   ```

2. **Mint Tokens**: Create new collectibles

   ```solidity
   string[] memory cids = ["QmHash1", "QmHash2"];
   uint256[] memory amounts = [1, 1];
   crurated.mint(cids, amounts);
   ```

3. **Update Status**: Track provenance changes

   ```solidity
   uint256[] memory tokenIds = [1, 2];
   Status[][] memory statuses = [[Status(1, block.timestamp, "Authenticated")]];
   crurated.update(tokenIds, statuses);
   ```

## Security Features

- **Soulbound Mechanism**: Tokens cannot be transferred after minting
- **Admin Controls**: Only owner can mint and update token data
- **Pause Functionality**: Contract can be paused in emergency
- **Upgrade Security**: UUPS pattern with owner-only upgrades

## Troubleshooting

### Common Issues

1. **"Missing required environment variables"**:

   - For local deployment: This shouldn't happen - the script handles it automatically
   - For mainnet/testnet: Ensure your `.env` file exists and contains all required variables

2. **"Insufficient funds"**:

   - For local: Anvil accounts are pre-funded
   - For testnet: Get free AVAX from the faucet
   - For mainnet: Ensure your wallet has enough AVAX

3. **"Anvil not running"**:
   - The script will automatically start Anvil
   - Or manually start with: `anvil`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes with clear messages
4. Submit a pull request

## Contact

- Security Contact: <security@crurated.com>
- Website: [https://crurated.com/](https://crurated.com/)
