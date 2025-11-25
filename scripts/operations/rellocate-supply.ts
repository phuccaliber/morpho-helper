import { ethers } from "hardhat";
import dotenv from "dotenv";
import addresses from "../addresses.json";
dotenv.config();

async function main() {
    const environment = process.env.ENVIRONMENT || "development";
    const configAddress = (addresses as any)[environment]!;

    const [caller] = await ethers.getSigners();

    const usdcVault = configAddress.vault;

    const morphoHelper = await ethers.getContractAt("MorphoHelper", configAddress.proxy);

    morphoHelper.connect(caller);

    const supplyAmount = 10e6;

    const tx = await morphoHelper["move(address,bytes32,bytes32,int256)"](usdcVault, configAddress.idleMarket, configAddress.obtcMarket, supplyAmount);
    await tx.wait();
    console.log("Supply transaction successful",  "at", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});