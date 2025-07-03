// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Crurated} from "../src/Crurated.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy
 * @notice Deployment script for Crurated contract
 * @dev Supports deployment to local anvil, Avalanche mainnet, and Fuji testnet
 */
contract Deploy is Script {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice First prefunded account address in anvil
    // Note: These are well-known addresses/private keys for anvil
    // They can be committed to the repo because they are not sensitive information
    // but they should NEVER be used in production
    address constant ANVIL_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Owner address for the contract
    address public owner;

    /// @notice Admin address for the contract
    address public admin;

    /// @notice Implementation contract address
    address public implementation;

    /// @notice Proxy contract address
    address public proxy;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event DeploymentComplete(
        address indexed implementation,
        address indexed proxy,
        address indexed owner,
        string network
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidOwner();
    error InvalidAdmin();
    error DeploymentFailed();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Main deployment function
     * @dev Reads environment variables for configuration
     */
    function run() external {
        // Get deployment configuration from environment
        owner = vm.envAddress("OWNER");
        admin = vm.envAddress("ADMIN");
        string memory network = vm.envString("NETWORK");

        if (owner == address(0)) revert InvalidOwner();
        if (admin == address(0)) revert InvalidAdmin();

        console2.log("Deploying Crurated contract...");
        console2.log("Network:", network);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        // Deploy implementation and proxy
        _deployContracts();

        console2.log("Deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        emit DeploymentComplete(implementation, proxy, owner, network);
    }

    /**
     * @notice Deploy to local anvil with prefunded account as owner
     * @dev Uses the first prefunded account (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
     */
    function runLocal() external {
        owner = ANVIL_ACCOUNT; // Anvil's first prefunded account
        admin = ANVIL_ACCOUNT; // Use same account for admin in local testing

        console2.log("Deploying to local anvil...");
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        _deployContractsLocal();

        console2.log("Local deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        emit DeploymentComplete(implementation, proxy, owner, "local");
    }

    /**
     * @notice Deploy to Avalanche mainnet
     * @dev Requires OWNER and ADMIN environment variables to be set
     */
    function runMainnet() external {
        owner = vm.envAddress("OWNER");
        admin = vm.envAddress("ADMIN");

        if (owner == address(0)) revert InvalidOwner();
        if (admin == address(0)) revert InvalidAdmin();

        // Get deployer address from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying to Avalanche mainnet...");
        console2.log("Deployer address:", deployer);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        _deployContracts();

        console2.log("Mainnet deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        emit DeploymentComplete(implementation, proxy, owner, "mainnet");
    }

    /**
     * @notice Deploy to Avalanche Fuji testnet
     * @dev Requires OWNER and ADMIN environment variables to be set
     */
    function runTestnet() external {
        owner = vm.envAddress("OWNER");
        admin = vm.envAddress("ADMIN");

        if (owner == address(0)) revert InvalidOwner();
        if (admin == address(0)) revert InvalidAdmin();

        // Get deployer address from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deploying to Avalanche Fuji testnet...");
        console2.log("Deployer address:", deployer);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        _deployContracts();

        console2.log("Testnet deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);
        console2.log("Admin:", admin);

        emit DeploymentComplete(implementation, proxy, owner, "testnet");
    }

    /**
     * @notice Deploy implementation and proxy contracts (for mainnet/testnet)
     * @dev Internal function that handles the actual deployment with private key
     */
    function _deployContracts() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation with initial owner and admin
        Crurated implementationContract = new Crurated(owner, admin);
        implementation = address(implementationContract);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Crurated.initialize.selector,
            owner,
            admin
        );

        // Deploy proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            implementation,
            initData
        );
        proxy = address(proxyContract);

        vm.stopBroadcast();

        if (implementation == address(0) || proxy == address(0)) {
            revert DeploymentFailed();
        }
    }

    /**
     * @notice Deploy implementation and proxy contracts (for local anvil)
     * @dev Internal function that handles local deployment without private key
     */
    function _deployContractsLocal() internal {
        // For local deployment, we use the anvil private key
        // Anvil's first account is already unlocked and has funds

        // Start broadcasting from the first anvil account using private key
        vm.startBroadcast(ANVIL_PRIVATE_KEY);

        // Deploy implementation with initial owner and admin
        Crurated implementationContract = new Crurated(owner, admin);
        implementation = address(implementationContract);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Crurated.initialize.selector,
            owner,
            admin
        );

        // Deploy proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            implementation,
            initData
        );
        proxy = address(proxyContract);

        vm.stopBroadcast();

        if (implementation == address(0) || proxy == address(0)) {
            revert DeploymentFailed();
        }
    }

    /**
     * @notice Verify deployment by calling a view function
     * @dev Useful for testing the deployment
     */
    function verifyDeployment() external view {
        Crurated crurated = Crurated(proxy);

        console2.log("Verifying deployment...");
        console2.log("Contract owner:", crurated.owner());
        console2.log("Contract admin:", crurated.hasRole(crurated.OPERATOR_ROLE(), admin));
        console2.log("Token count:", crurated.tokenCount());
        console2.log("Next status ID:", crurated.nextStatusId());

        require(crurated.owner() == owner, "Owner mismatch");
        require(crurated.hasRole(crurated.OPERATOR_ROLE(), admin), "Admin mismatch");
        console2.log("Deployment verification successful!");
    }
}