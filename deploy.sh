#!/bin/bash

# Crurated Contract Deployment Script
# Supports local anvil, Avalanche mainnet, and Fuji testnet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required environment variables are set
check_env_vars() {
    local missing_vars=()

    if [ -z "$PRIVATE_KEY" ]; then
        missing_vars+=("PRIVATE_KEY")
    fi

    if [ -z "$OWNER" ]; then
        missing_vars+=("OWNER")
    fi

    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables: ${missing_vars[*]}"
        print_status "Please set them in your .env file or export them"
        exit 1
    fi
}

# Function to check if required environment variables are set (excluding PRIVATE_KEY for local)
check_env_vars_local() {
    local missing_vars=()

    if [ -z "$OWNER" ]; then
        missing_vars+=("OWNER")
    fi

    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_warning "Missing OWNER environment variable for local deployment"
        print_status "Using Anvil's first prefunded account as owner"
    fi
}

# Function to load environment variables from .env file
load_env() {
    if [ -f ".env" ]; then
        print_status "Loading environment variables from .env file"
        export $(cat .env | grep -v '^#' | xargs)
    fi
}

# Function to deploy to local anvil
deploy_local() {
    print_status "Starting local anvil deployment..."

    # Check if anvil is running
    if ! curl -s http://localhost:8545 > /dev/null 2>&1; then
        print_warning "Anvil not running. Starting anvil..."
        anvil &
        sleep 2
    fi

    # Deploy using local configuration (no private key required)
    forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --broadcast --sig "runLocal()"

    print_success "Local deployment completed!"
}

# Function to deploy to Avalanche mainnet
deploy_mainnet() {
    print_status "Starting Avalanche mainnet deployment..."

    check_env_vars

    # Set network environment variable
    export NETWORK="mainnet"

    # Deploy to mainnet
    forge script script/Deploy.s.sol:Deploy --rpc-url $AVALANCHE_MAINNET_RPC --broadcast --verify --sig "runMainnet()"

    print_success "Mainnet deployment completed!"
}

# Function to deploy to Avalanche Fuji testnet
deploy_testnet() {
    print_status "Starting Avalanche Fuji testnet deployment..."

    check_env_vars

    # Set network environment variable
    export NETWORK="testnet"

    # Deploy to testnet
    forge script script/Deploy.s.sol:Deploy --rpc-url $AVALANCHE_FUJI_RPC --broadcast --verify --sig "runTestnet()"

    print_success "Testnet deployment completed!"
}

# Function to verify deployment
verify_deployment() {
    local contract_address=$1
    local rpc_url=$2

    if [ -z "$contract_address" ]; then
        print_error "Contract address required for verification"
        exit 1
    fi

    print_status "Verifying deployment at $contract_address..."

    # Call verification function
    forge script script/Deploy.s.sol:Deploy --rpc-url $rpc_url --sig "verifyDeployment()" --target-contract $contract_address
}

# Function to show help
show_help() {
    echo "Crurated Contract Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  local     Deploy to local anvil (uses prefunded account as owner, no private key needed)"
    echo "  mainnet   Deploy to Avalanche mainnet"
    echo "  testnet   Deploy to Avalanche Fuji testnet"
    echo "  verify    Verify deployment (requires contract address)"
    echo "  help      Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  PRIVATE_KEY              Private key for deployment (not required for local)"
    echo "  OWNER                    Owner address for the contract (optional for local)"
    echo "  AVALANCHE_MAINNET_RPC    RPC URL for Avalanche mainnet"
    echo "  AVALANCHE_FUJI_RPC       RPC URL for Avalanche Fuji testnet"
    echo ""
    echo "Examples:"
    echo "  $0 local                 # Deploy to local anvil (no setup required)"
    echo "  $0 mainnet               # Deploy to mainnet (requires .env setup)"
    echo "  $0 testnet               # Deploy to testnet (requires .env setup)"
    echo "  $0 verify 0x1234... http://localhost:8545"
}

# Main script logic
main() {
    # Load environment variables
    load_env

    case "${1:-help}" in
        "local")
            deploy_local
            ;;
        "mainnet")
            deploy_mainnet
            ;;
        "testnet")
            deploy_testnet
            ;;
        "verify")
            verify_deployment "$2" "$3"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"