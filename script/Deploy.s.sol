// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/HardenedEvictionVault.sol";
import "../src/modules/TimelockExecutor.sol";

//Deployment script for the HardenedEvictionVault and associated modules.
contract DeployScript is Script {
    function run() external {
        // Retrieve deployment private key from environment
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Define Multisig Owners
        // In a real deployment, these should be unique hardware wallets or trusted entities.
        address[] memory owners = new address[](3);
        owners[0] = deployer;                   // Deployer as first owner for setup
        owners[1] = address(0x111);             // Placeholder owner 2
        owners[2] = address(0x222);             // Placeholder owner 3

        uint256 threshold = 2; // 2-of-3 multisig

        // 2. Deploy HardenedEvictionVault
        // This initializes the internal multisig, roles, and vault logic.
        HardenedEvictionVault vault = new HardenedEvictionVault(owners, threshold);
        
        console.log("HardenedEvictionVault deployed at:", address(vault));

        // 3. Deploy Standalone TimelockExecutor
        // While the vault has an internal timelock for its multisig, 
        // a standalone executor is useful for managing external contract interactions.
        TimelockExecutor externalTimelock = new TimelockExecutor(address(vault));
        
        console.log("TimelockExecutor deployed at:", address(externalTimelock));

        // 4. Post-Deployment Configuration
        // The vault is its own admin. Any further role assignments (e.g., adding specific 
        // airdrop managers or pausers beyond the multisig itself) should be done 
        // via a multisig transaction to maintain decentralization.
        
        console.log("Deployment Successful.");
        console.log("Vault Threshold:", vault.getThreshold());
        console.log("Vault Owners:");
        for (uint256 i = 0; i < owners.length; i++) {
            console.log("- ", owners[i]);
        }

        vm.stopBroadcast();
    }
}
