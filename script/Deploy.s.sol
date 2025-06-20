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
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Owner address for the contract
    address public owner;

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
        string memory network = vm.envString("NETWORK");

        if (owner == address(0)) revert InvalidOwner();

        console2.log("Deploying Crurated contract...");
        console2.log("Network:", network);
        console2.log("Owner:", owner);

        // Deploy implementation and proxy
        _deployContracts();

        console2.log("Deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);

        emit DeploymentComplete(implementation, proxy, owner, network);
    }

    /**
     * @notice Deploy to local anvil with prefunded account as owner
     * @dev Uses the first prefunded account (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
     */
    function runLocal() external {
        owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil's first prefunded account

        console2.log("Deploying to local anvil...");
        console2.log("Owner:", owner);

        _deployContractsLocal();

        console2.log("Local deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);

        emit DeploymentComplete(implementation, proxy, owner, "local");
    }

    /**
     * @notice Deploy to Avalanche mainnet
     * @dev Requires OWNER environment variable to be set
     */
    function runMainnet() external {
        owner = vm.envAddress("OWNER");

        if (owner == address(0)) revert InvalidOwner();

        console2.log("Deploying to Avalanche mainnet...");
        console2.log("Owner:", owner);

        _deployContracts();

        console2.log("Mainnet deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);

        emit DeploymentComplete(implementation, proxy, owner, "mainnet");
    }

    /**
     * @notice Deploy to Avalanche Fuji testnet
     * @dev Requires OWNER environment variable to be set
     */
    function runTestnet() external {
        owner = vm.envAddress("OWNER");

        if (owner == address(0)) revert InvalidOwner();

        console2.log("Deploying to Avalanche Fuji testnet...");
        console2.log("Owner:", owner);

        _deployContracts();

        console2.log("Testnet deployment complete!");
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxy);
        console2.log("Owner:", owner);

        emit DeploymentComplete(implementation, proxy, owner, "testnet");
    }

    /**
     * @notice Deploy implementation and proxy contracts (for mainnet/testnet)
     * @dev Internal function that handles the actual deployment with private key
     */
    function _deployContracts() internal {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation
        Crurated implementationContract = new Crurated();
        implementation = address(implementationContract);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Crurated.initialize.selector,
            owner
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
        // For local deployment, we can use the default account without private key
        // Anvil's first account is already unlocked and has funds

        // Deploy implementation
        Crurated implementationContract = new Crurated();
        implementation = address(implementationContract);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Crurated.initialize.selector,
            owner
        );

        // Deploy proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            implementation,
            initData
        );
        proxy = address(proxyContract);

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
        console2.log("Token count:", crurated.tokenCount());
        console2.log("Next status ID:", crurated.nextStatusId());

        require(crurated.owner() == owner, "Owner mismatch");
        console2.log("Deployment verification successful!");
    }
}