import { ethers, run, network } from "hardhat";

/**
 * Deploy and verify the MorphoHelperProxy contract
 * 
 * Usage:
 * 
 * 1. Deploy to a specific network (with env variables):
 *    npx hardhat run scripts/deployments/deploy-morpho-helper-proxy.ts --network sepolia
 *    npx hardhat run scripts/deployments/deploy-morpho-helper-proxy.ts --network base_sepolia
 * 
 * 2. Deploy to local network:
 *    npx hardhat run scripts/deployments/deploy-morpho-helper-proxy.ts --network localnet
 * 
 * Note: Make sure to configure your .env file with:
 *   - PRIVATE_KEY
 *   - IMPLEMENTATION_ADDRESS (MorphoHelper implementation address)
 *   - INITIAL_ADMIN (optional, defaults to deployer address)
 *   - SEPOLIA_RPC_URL (for Sepolia)
 *   - BASE_SEPOLIA_RPC_URL (for Base Sepolia)
 *   - ETHERSCAN_API_KEY (for verification)
 */

async function main() {
  console.log("===========================================");
  console.log("MorphoHelperProxy Deployment Script");
  console.log("===========================================");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);
  console.log("Network:", network.name);
  console.log("Chain ID:", network.config.chainId);

  // Get deployer balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Deployer balance:", ethers.formatEther(balance), "ETH");

  // Get implementation address from environment variable
  const implementationAddress = "0x13edC544A0e910ff4AA40Ba2F9dcf50B65A66a53";
  if (!implementationAddress) {
    throw new Error("IMPLEMENTATION_ADDRESS not set in .env file");
  }
  console.log("Implementation address:", implementationAddress);

  // Get initial admin address from environment variable (or use deployer)
  const initialAdmin = process.env.INITIAL_ADMIN || deployer.address;
  console.log("Initial admin:", initialAdmin);
  console.log("===========================================");

  // Validate implementation address
  const implementationCode = await ethers.provider.getCode(implementationAddress);
  if (implementationCode === "0x") {
    throw new Error(`No contract found at implementation address: ${implementationAddress}`);
  }
  console.log("✅ Implementation contract verified at address");

  // Deploy MorphoHelperProxy
  console.log("\nDeploying MorphoHelperProxy...");
  const MorphoHelperProxy = await ethers.getContractFactory("MorphoHelperProxy");
  const proxy = await MorphoHelperProxy.deploy(implementationAddress, initialAdmin);
  
  // Wait for deployment to complete
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  
  console.log("✅ MorphoHelperProxy deployed at:", proxyAddress);

  // Display deployment summary
  console.log("\n===========================================");
  console.log("Deployment Summary");
  console.log("===========================================");
  console.log("Proxy Address:", proxyAddress);
  console.log("Implementation Address:", implementationAddress);
  console.log("Initial Admin:", initialAdmin);
  console.log("Deployer Address:", deployer.address);
  console.log("Network:", network.name);
  console.log("===========================================");

  // Verify contract on Etherscan/Basescan (skip for local networks)
  if (network.name !== "hardhat" && network.name !== "localnet" && network.name !== "localhost") {
    console.log("\n⏳ Waiting 60 seconds before verification...");
    await new Promise(resolve => setTimeout(resolve, 60000)); // Wait 60 seconds for Etherscan to index

    console.log("\n===========================================");
    console.log("Verifying Contract on Block Explorer");
    console.log("===========================================");
    
    try {
      await run("verify:verify", {
        address: proxyAddress,
        constructorArguments: [implementationAddress, initialAdmin],
        contract: "src/MorphoHelperProxy.sol:MorphoHelperProxy",
      });
      console.log("✅ Contract verified successfully!");
    } catch (error: any) {
      if (error.message.toLowerCase().includes("already verified")) {
        console.log("✅ Contract is already verified!");
      } else {
        console.error("❌ Verification failed:", error.message);
        console.log("\nManual verification command:");
        console.log(`npx hardhat verify --network ${network.name} ${proxyAddress} ${implementationAddress} ${initialAdmin}`);
      }
    }
  } else {
    console.log("\n⚠️  Skipping verification for local network");
  }

  // Display next steps
  console.log("\n===========================================");
  console.log("Next Steps");
  console.log("===========================================");
  console.log("1. Interact with the contract using the Proxy address:", proxyAddress);
  console.log("2. The contract is already initialized with admin:", initialAdmin);
  console.log("3. Grant additional roles as needed:");
  console.log("   - OPERATOR_ROLE");
  console.log("   - UPGRADER_ROLE");
  console.log("===========================================");

  // Display role information
  console.log("\n===========================================");
  console.log("Role Information");
  console.log("===========================================");
  console.log("DEFAULT_ADMIN_ROLE:", ethers.ZeroHash);
  console.log("OPERATOR_ROLE:", ethers.keccak256(ethers.toUtf8Bytes("OPERATOR_ROLE")));
  console.log("UPGRADER_ROLE:", ethers.keccak256(ethers.toUtf8Bytes("UPGRADER_ROLE")));
  console.log("===========================================");

  // Save deployment info
  console.log("\n===========================================");
  console.log("Save This Information");
  console.log("===========================================");
  console.log(JSON.stringify({
    network: network.name,
    chainId: network.config.chainId,
    proxy: proxyAddress,
    implementation: implementationAddress,
    initialAdmin: initialAdmin,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
  }, null, 2));
  console.log("===========================================");

  // Interaction example
  console.log("\n===========================================");
  console.log("Interaction Example (using ethers.js)");
  console.log("===========================================");
  console.log(`
const morphoHelper = await ethers.getContractAt("MorphoHelper", "${proxyAddress}");

// Check if address has admin role
const hasAdminRole = await morphoHelper.hasRole(ethers.ZeroHash, "${initialAdmin}");
console.log("Has admin role:", hasAdminRole);

// Grant operator role
await morphoHelper.grantRole(
  ethers.keccak256(ethers.toUtf8Bytes("OPERATOR_ROLE")),
  "0x..."
);
  `);
  console.log("===========================================");
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

