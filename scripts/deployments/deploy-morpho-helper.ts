import { ethers, run, network } from "hardhat";

/**
 * Deploy and verify the MorphoHelper contract
 * 
 * Usage:
 * 
 * 1. Deploy to a specific network:
 *    npx hardhat run scripts/deployments/deploy-morpho-helper.ts --network sepolia
 *    npx hardhat run scripts/deployments/deploy-morpho-helper.ts --network base_sepolia
 * 
 * 2. Deploy to local network:
 *    npx hardhat run scripts/deployments/deploy-morpho-helper.ts --network localnet
 * 
 * Note: Make sure to configure your .env file with:
 *   - PRIVATE_KEY
 *   - SEPOLIA_RPC_URL (for Sepolia)
 *   - BASE_SEPOLIA_RPC_URL (for Base Sepolia)
 *   - ETHERSCAN_API_KEY (for verification)
 */

async function main() {
  console.log("===========================================");
  console.log("MorphoHelper Deployment Script");
  console.log("===========================================");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);
  console.log("Network:", network.name);
  console.log("Chain ID:", network.config.chainId);

  // Get deployer balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Deployer balance:", ethers.formatEther(balance), "ETH");
  console.log("===========================================");

  // Deploy MorphoHelper
  console.log("\nDeploying MorphoHelper implementation...");
  const MorphoHelper = await ethers.getContractFactory("MorphoHelper");
  const morphoHelper = await MorphoHelper.deploy();
  
  // Wait for deployment to complete
  await morphoHelper.waitForDeployment();
  const implementationAddress = await morphoHelper.getAddress();
  
  console.log("✅ MorphoHelper deployed at:", implementationAddress);

  // Display deployment summary
  console.log("\n===========================================");
  console.log("Deployment Summary");
  console.log("===========================================");
  console.log("Implementation Address:", implementationAddress);
  console.log("Deployer Address:", deployer.address);
  console.log("Network:", network.name);
  console.log("===========================================");

  // Verify contract on Etherscan/Basescan (skip for local networks)
  if (network.name !== "hardhat" && network.name !== "localnet" && network.name !== "localhost") {
    console.log("\n⏳ Waiting 60 seconds before verification...");
    await new Promise(resolve => setTimeout(resolve, 60000)); // Wait 30 seconds for Etherscan to index

    console.log("\n===========================================");
    console.log("Verifying Contract on Block Explorer");
    console.log("===========================================");
    
    try {
      await run("verify:verify", {
        address: implementationAddress,
        constructorArguments: [],
      });
      console.log("✅ Contract verified successfully!");
    } catch (error: any) {
      if (error.message.toLowerCase().includes("already verified")) {
        console.log("✅ Contract is already verified!");
      } else {
        console.error("❌ Verification failed:", error.message);
        console.log("\nManual verification command:");
        console.log(`npx hardhat verify --network ${network.name} ${implementationAddress}`);
      }
    }
  } else {
    console.log("\n⚠️  Skipping verification for local network");
  }

  // Display next steps
  console.log("\n===========================================");
  console.log("Next Steps");
  console.log("===========================================");
  console.log("1. Deploy a proxy contract pointing to:", implementationAddress);
  console.log("2. Initialize the contract via proxy with an admin address");
  console.log("3. Grant roles (OPERATOR_ROLE, UPGRADER_ROLE) as needed");
  console.log("===========================================");

  // Save deployment info
  console.log("\n===========================================");
  console.log("Save This Information");
  console.log("===========================================");
  console.log(JSON.stringify({
    network: network.name,
    chainId: network.config.chainId,
    implementation: implementationAddress,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
  }, null, 2));
  console.log("===========================================");
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

