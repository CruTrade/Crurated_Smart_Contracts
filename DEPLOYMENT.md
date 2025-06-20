# Crurated Contract Deployment Guide

This guide explains how to deploy the Crurated contract to different networks using Foundry.

## Prerequisites

1. **Foundry Installation**: Make sure you have Foundry installed

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Dependencies**: Install project dependencies

   ```bash
   forge soldeer install
   ```

3. **Environment Setup**: Copy the example environment file and configure it

   ```bash
   cp env.example .env
   # Edit .env with your actual values
   ```

## Environment Configuration

Create a `.env` file with the following variables:

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

**Note**: For local deployment, you don't need to set `PRIVATE_KEY` or `OWNER` - the script will use Anvil's prefunded accounts automatically.

### Getting RPC URLs

- **Avalanche Mainnet**: `https://api.avax.network/ext/bc/C/rpc`
- **Avalanche Fuji Testnet**: `https://api.avax-test.network/ext/bc/C/rpc`
- **Local Anvil**: `http://localhost:8545` (automatically started)

### Getting API Keys

For contract verification on Avalanche:

1. Go to [Snowtrace](https://snowtrace.io/)
2. Create an account and get your API key
3. Add it to your `.env` file

## Deployment Options

### 1. Local Development (Anvil) - No Setup Required

Deploy to a local Anvil instance for testing:

```bash
# Make the deployment script executable
chmod +x deploy.sh

# Deploy to local anvil (no .env file needed!)
./deploy.sh local
```

This will:

- Start Anvil if it's not running
- Use the first prefunded account as the owner (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
- Deploy both implementation and proxy contracts
- Verify the deployment

**Perfect for quick testing and development!**

### 2. Avalanche Fuji Testnet

Deploy to Avalanche's Fuji testnet:

```bash
./deploy.sh testnet
```

**Requirements:**

- `PRIVATE_KEY` in `.env`
- `OWNER` in `.env`
- `AVALANCHE_FUJI_RPC` in `.env`
- Testnet AVAX tokens in your wallet

### 3. Avalanche Mainnet

Deploy to Avalanche mainnet:

```bash
./deploy.sh mainnet
```

**Requirements:**

- `PRIVATE_KEY` in `.env`
- `OWNER` in `.env`
- `AVALANCHE_MAINNET_RPC` in `.env`
- Mainnet AVAX tokens in your wallet

## Manual Deployment

If you prefer to use Foundry commands directly:

### Local Deployment (No Private Key Required)

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --broadcast --verify --sig "runLocal()"
```

### Testnet Deployment

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $AVALANCHE_FUJI_RPC --broadcast --verify --sig "runTestnet()"
```

### Mainnet Deployment

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url $AVALANCHE_MAINNET_RPC --broadcast --verify --sig "runMainnet()"
```

## Contract Architecture

The deployment creates two contracts:

1. **Implementation Contract**: Contains the actual contract logic
2. **Proxy Contract**: Points to the implementation and stores state

This UUPS (Universal Upgradeable Proxy Standard) pattern allows for:

- Gas-efficient upgrades
- State preservation during upgrades
- Separation of logic and storage

## Verification

After deployment, verify your contract:

```bash
./deploy.sh verify <PROXY_ADDRESS> <RPC_URL>
```

Example:

```bash
./deploy.sh verify 0x1234... http://localhost:8545
```

## Post-Deployment

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

## Quick Start for Development

Want to test your contract immediately? Just run:

```bash
./deploy.sh local
```

That's it! No configuration needed. The script will:

- Start Anvil automatically
- Deploy your contract
- Use prefunded accounts
- Show you the contract addresses

## Troubleshooting

### Common Issues

1. **"Missing required environment variables"**

   - For local deployment: This shouldn't happen - the script handles it automatically
   - For mainnet/testnet: Ensure your `.env` file exists and contains all required variables

2. **"Insufficient funds"**

   - For local: Anvil accounts are pre-funded
   - For testnet: Get free AVAX from the faucet
   - For mainnet: Ensure your wallet has enough AVAX

3. **"Anvil not running"**
   - The script will automatically start Anvil
   - Or manually start with: `anvil`

### Gas Optimization

The contract is optimized for gas efficiency with:

- Batch operations for multiple tokens
- Efficient storage patterns
- Minimal external calls

### Security Considerations

- Keep your private key secure and never commit it to version control
- Use a dedicated deployment wallet
- Test thoroughly on testnet before mainnet deployment
- Consider using a multisig wallet as the owner for mainnet

## Support

For deployment issues or questions:

1. Check the Foundry documentation
2. Review the contract source code
3. Test on local anvil first (no setup required!)
4. Use testnet for integration testing
