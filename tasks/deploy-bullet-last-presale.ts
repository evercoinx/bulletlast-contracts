import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { task, types } from "hardhat/config";
import { getSigner } from "../utils/account";
import { isLocalNetwork, Network } from "../utils/network";

interface TaskParams {
    saleToken: string;
    etherPriceFeed: string;
    usdtToken: string;
    treasury: string;
    vestingDuration: number;
}

task("deploy:bullet-last-presale")
    .setDescription("Deploy the BulletLastPresale contract")
    .addParam<string>("saleToken", "Sale token address", undefined, types.string)
    .addParam<string>(
        "etherPriceFeed",
        "Chainlink ether price feed address",
        undefined,
        types.string
    )
    .addParam<string>("usdtToken", "USDT token address", undefined, types.string)
    .addParam<string>("treasury", "Treasury address", undefined, types.string)
    .addParam<number>("vestingDuration", "Vesting duration (in seconds)", undefined, types.int)
    .setAction(
        async (
            {
                saleToken: saleTokenAddress,
                etherPriceFeed: etherPriceFeedAddress,
                usdtToken: usdtTokenAddress,
                treasury: treasuryAddress,
                vestingDuration,
            }: TaskParams,
            { ethers, network, run, upgrades }
        ) => {
            if (!ethers.isAddress(saleTokenAddress)) {
                throw new Error("Invalid sale token address");
            }
            if (!ethers.isAddress(etherPriceFeedAddress)) {
                throw new Error("Invalid Ether price feed address");
            }
            if (!ethers.isAddress(usdtTokenAddress)) {
                throw new Error("Invalid USDT token address");
            }
            if (!ethers.isAddress(treasuryAddress)) {
                throw new Error("Invalid treasury address");
            }
            if (vestingDuration === 0) {
                throw new Error("Zero vesting duration");
            }

            const networkName = network.name as Network;
            console.log(`Network name: ${networkName}`);
            if (!isLocalNetwork(networkName)) {
                await run(TASK_CLEAN);
            }
            await run(TASK_COMPILE);

            const deployer = await getSigner(ethers, network.provider, network.config.from);
            const BulletLastPresale = await ethers.getContractFactory(
                "BulletLastPresale",
                deployer
            );

            const bulletLastPresale = await upgrades.deployProxy(BulletLastPresale, [
                saleTokenAddress,
                etherPriceFeedAddress,
                usdtTokenAddress,
                treasuryAddress,
                vestingDuration,
            ]);
            await bulletLastPresale.waitForDeployment();

            const bulletLastPresaleAddress = await bulletLastPresale.getAddress();
            console.log(`BulletLastPresale Proxy deployed at ${bulletLastPresaleAddress}`);

            const implementationAddress =
                await upgrades.erc1967.getImplementationAddress(bulletLastPresaleAddress);
            console.log(`BulletLastPresale Implementation deployed at ${implementationAddress}`);

            const adminAddress = await upgrades.erc1967.getAdminAddress(bulletLastPresaleAddress);
            console.log(`BulletLastPresale Admin deployed at ${adminAddress}`);
        }
    );
