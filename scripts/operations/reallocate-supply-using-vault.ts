import { ethers } from "hardhat";
import addresses from "../addresses.json";
import { MaxUint256 } from "ethers";

async function main() {
    const environment = process.env.ENVIRONMENT || "development";
    const configAddress = (addresses as any)[environment]!;

    const [caller] = await ethers.getSigners();

    const usdcVault = configAddress.vault;

    const vault = await ethers.getContractAt("IMetaMorpho", usdcVault);
    const morpho = await ethers.getContractAt("IMorpho", configAddress.morpho);

    const idleMarketParams = await morpho.idToMarketParams(configAddress.idleMarket);
    const obtcMarketParams = await morpho.idToMarketParams(configAddress.obtcMarket);

    await vault.connect(caller);

    const tx = await vault.reallocate([
        {
            marketParams: {
                loanToken: idleMarketParams.loanToken,
                collateralToken: idleMarketParams.collateralToken,
                oracle: idleMarketParams.oracle,
                irm: idleMarketParams.irm,
                lltv: idleMarketParams.lltv,
            },
            assets: 110e6,
        },
        {
            marketParams: {
                loanToken: obtcMarketParams.loanToken,
                collateralToken: obtcMarketParams.collateralToken,
                oracle: obtcMarketParams.oracle,
                irm: obtcMarketParams.irm,
                lltv: obtcMarketParams.lltv,
            },
            assets: MaxUint256,
        }
    ]);

    await tx.wait();

    console.log("Reallocation transaction successful", "at", tx.hash);

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});