import { ethers, network } from "hardhat";

/**
 * Query information from the MorphoHelperProxy contract
 * 
 * Usage:
 * 
 * 1. Query on a specific network:
 *    npx hardhat run scripts/operations/query-morpho-helper.ts --network sepolia
 *    npx hardhat run scripts/operations/query-morpho-helper.ts --network base_sepolia
 * 
 * 2. Query on local network:
 *    npx hardhat run scripts/operations/query-morpho-helper.ts --network localnet
 * 
 * Note: Make sure to configure your .env file with:
 *   - PROXY_ADDRESS (the deployed MorphoHelperProxy address)
 *   - SEPOLIA_RPC_URL (for Sepolia)
 *   - BASE_SEPOLIA_RPC_URL (for Base Sepolia)
 */

async function main() {
  console.log("===========================================");
  console.log("MorphoHelperProxy Query Script");
  console.log("===========================================");
  console.log("Network:", network.name);
  console.log("Chain ID:", network.config.chainId);
  console.log("===========================================");

  // Get proxy address from environment variable
  const proxyAddress = "0xD682B123BA512927bFDC4A744bFc5CF47b257191";
  console.log("Proxy Address:", proxyAddress);

  // Validate proxy address
  const proxyCode = await ethers.provider.getCode(proxyAddress);
  if (proxyCode === "0x") {
    throw new Error(`No contract found at proxy address: ${proxyAddress}`);
  }
  console.log("✅ Proxy contract found at address");

  // Connect to the proxy using MorphoHelper ABI
  const morphoHelper = await ethers.getContractAt("MorphoHelper", proxyAddress);
  console.log("\n===========================================");
  console.log("Querying Contract Information");
  console.log("===========================================");

  try {
    // Query morpho address
    const morphoAddress = await morphoHelper.morpho();
    console.log("Morpho Address:", morphoAddress);

    // Query public allocator address
    const publicAllocatorAddress = await morphoHelper.public_allocator();
    console.log("Public Allocator Address:", publicAllocatorAddress);

    // Query role constants
    console.log("\n===========================================");
    console.log("Role Information");
    console.log("===========================================");
    
    const operatorRole = await morphoHelper.OPERATOR_ROLE();
    console.log("OPERATOR_ROLE:", operatorRole);
    
    const upgraderRole = await morphoHelper.UPGRADER_ROLE();
    console.log("UPGRADER_ROLE:", upgraderRole);
    
    const defaultAdminRole = ethers.ZeroHash;
    console.log("DEFAULT_ADMIN_ROLE:", defaultAdminRole);

    // Get the deployer/caller account
    const [caller] = await ethers.getSigners();
    console.log("\n===========================================");
    console.log("Role Assignments for:", caller.address);
    console.log("===========================================");
    
    const hasAdminRole = await morphoHelper.hasRole(defaultAdminRole, caller.address);
    console.log("Has DEFAULT_ADMIN_ROLE:", hasAdminRole);
    
    const hasOperatorRole = await morphoHelper.hasRole(operatorRole, caller.address);
    console.log("Has OPERATOR_ROLE:", hasOperatorRole);
    
    const hasUpgraderRole = await morphoHelper.hasRole(upgraderRole, caller.address);
    console.log("Has UPGRADER_ROLE:", hasUpgraderRole);

    // Get implementation address (from ERC1967 proxy)
    console.log("\n===========================================");
    console.log("Proxy Information");
    console.log("===========================================");
    
    // ERC1967 implementation slot: keccak256("eip1967.proxy.implementation") - 1
    const implementationSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
    const implementationBytes = await ethers.provider.getStorage(proxyAddress, implementationSlot);
    const implementationAddress = ethers.getAddress("0x" + implementationBytes.slice(-40));
    console.log("Implementation Address:", implementationAddress);

    // Summary JSON
    console.log("\n===========================================");
    console.log("Summary (JSON)");
    console.log("===========================================");
    console.log(JSON.stringify({
      network: network.name,
      chainId: network.config.chainId,
      proxy: proxyAddress,
      implementation: implementationAddress,
      morpho: morphoAddress,
      publicAllocator: publicAllocatorAddress,
      roles: {
        OPERATOR_ROLE: operatorRole,
        UPGRADER_ROLE: upgraderRole,
        DEFAULT_ADMIN_ROLE: defaultAdminRole,
      },
      caller: {
        address: caller.address,
        hasAdminRole,
        hasOperatorRole,
        hasUpgraderRole,
      },
    }, null, 2));
    console.log("===========================================");

  } catch (error: any) {
    console.error("\n❌ Error querying contract:", error.message);
    throw error;
  }

  console.log("\n✅ Query completed successfully!");
}

// Execute query
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

