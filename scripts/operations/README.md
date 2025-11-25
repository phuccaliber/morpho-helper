# MorphoHelper Operations Scripts

This directory contains scripts for querying and interacting with deployed MorphoHelper contracts.

---

## 📋 Prerequisites

1. **Deployed MorphoHelperProxy contract**
2. **RPC endpoint** for your target network
3. **Environment variables** configured in `.env` file

---

## 🔧 Setup

### 1. Configure Environment Variables

Edit your `.env` file in the project root:

```env
# Proxy address (required)
PROXY_ADDRESS=0x...

# RPC URLs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Private key (only needed if you want to check your own roles)
PRIVATE_KEY=your_private_key_here
```

---

## 🔍 Query Contract Information

### Script: `query-morpho-helper.ts`

This script queries information from a deployed MorphoHelperProxy contract.

**What it queries:**
- Morpho Blue address
- Public Allocator address
- Role constants (OPERATOR_ROLE, UPGRADER_ROLE, DEFAULT_ADMIN_ROLE)
- Role assignments for the caller
- Implementation address (via ERC1967 proxy slot)

### Usage

```bash
# Query on Sepolia
npx hardhat run scripts/operations/query-morpho-helper.ts --network sepolia

# Query on Base Sepolia
npx hardhat run scripts/operations/query-morpho-helper.ts --network base_sepolia

# Query on local network
npx hardhat run scripts/operations/query-morpho-helper.ts --network localnet
```

### Example Output

```
===========================================
MorphoHelperProxy Query Script
===========================================
Network: sepolia
Chain ID: 11155111
===========================================
Proxy Address: 0x...
✅ Proxy contract found at address

===========================================
Querying Contract Information
===========================================
Morpho Address: 0xEB4162C6E363e7C925395E82a8fe7BE78bc74A5f
Public Allocator Address: 0x646f25D09C030b5B61e4dc0a06CAe98Ecf3CbB9A

===========================================
Role Information
===========================================
OPERATOR_ROLE: 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929
UPGRADER_ROLE: 0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3
DEFAULT_ADMIN_ROLE: 0x0000000000000000000000000000000000000000000000000000000000000000

===========================================
Role Assignments for: 0x...
===========================================
Has DEFAULT_ADMIN_ROLE: true
Has OPERATOR_ROLE: true
Has UPGRADER_ROLE: true

===========================================
Proxy Information
===========================================
Implementation Address: 0x...

===========================================
Summary (JSON)
===========================================
{
  "network": "sepolia",
  "chainId": 11155111,
  "proxy": "0x...",
  "implementation": "0x...",
  "morpho": "0xEB4162C6E363e7C925395E82a8fe7BE78bc74A5f",
  "publicAllocator": "0x646f25D09C030b5B61e4dc0a06CAe98Ecf3CbB9A",
  "roles": {
    "OPERATOR_ROLE": "0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929",
    "UPGRADER_ROLE": "0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3",
    "DEFAULT_ADMIN_ROLE": "0x0000000000000000000000000000000000000000000000000000000000000000"
  },
  "caller": {
    "address": "0x...",
    "hasAdminRole": true,
    "hasOperatorRole": true,
    "hasUpgraderRole": true
  }
}
===========================================

✅ Query completed successfully!
```

---

## 🛠️ Programmatic Usage

You can also use these scripts as modules in your own code:

```typescript
import { ethers } from "hardhat";

async function queryMorphoHelper(proxyAddress: string) {
  const morphoHelper = await ethers.getContractAt("MorphoHelper", proxyAddress);
  
  // Get Morpho address
  const morphoAddress = await morphoHelper.morpho();
  console.log("Morpho:", morphoAddress);
  
  // Get Public Allocator address
  const publicAllocatorAddress = await morphoHelper.public_allocator();
  console.log("Public Allocator:", publicAllocatorAddress);
  
  // Check roles
  const operatorRole = await morphoHelper.OPERATOR_ROLE();
  const hasOperatorRole = await morphoHelper.hasRole(operatorRole, "0x...");
  console.log("Has operator role:", hasOperatorRole);
}
```

---

## 📚 Additional Information

### Role Descriptions

- **DEFAULT_ADMIN_ROLE**: Can grant/revoke all roles, including itself
- **OPERATOR_ROLE**: Can perform vault operations (reallocate, set queues, etc.)
- **UPGRADER_ROLE**: Can upgrade the contract implementation and modify core settings

### ERC1967 Proxy Pattern

The MorphoHelperProxy uses the ERC1967 transparent proxy pattern:
- All calls are delegated to the implementation contract
- The implementation address is stored at a specific storage slot
- The proxy can be upgraded by accounts with the UPGRADER_ROLE

### Storage Slot for Implementation

```solidity
// ERC1967 implementation slot
bytes32 slot = keccak256("eip1967.proxy.implementation") - 1;
// = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

---

## 🐛 Troubleshooting

### Error: "PROXY_ADDRESS not set in .env file"

Add the proxy address to your `.env` file:
```env
PROXY_ADDRESS=0x...
```

### Error: "No contract found at proxy address"

- Verify the proxy address is correct
- Ensure you're connected to the correct network
- Check that the contract was actually deployed

### Error: "call revert exception"

- The proxy might not be initialized
- You might be calling a function that doesn't exist
- The implementation contract might have issues

---

## 📚 Additional Resources

- [OpenZeppelin UUPS Upgrades](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
- [ERC1967 Standard](https://eips.ethereum.org/EIPS/eip-1967)
- [Morpho Blue Documentation](https://docs.morpho.org/)
- [Hardhat Documentation](https://hardhat.org/docs)

