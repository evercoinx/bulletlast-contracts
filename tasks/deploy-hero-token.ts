import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { task, types } from "hardhat/config";
import { getSigner } from "../utils/account";
import { isLocalNetwork, Network } from "../utils/network";

interface TaskParams {
    owningTreasury: string;
    feeTreasury: string;
    feePercentage: number;
}

task("deploy:hero-token")
    .setDescription("Deploy the HeroToken contract")
    .addParam<string>("owningTreasury", "Owning treasury address", undefined, types.string)
    .addParam<string>("feeTreasury", "Fee treasury address", undefined, types.string)
    .addParam<number>("feePercentage", "Fee percentage", undefined, types.int)
    .setAction(
        async (
            {
                owningTreasury: owningTreasuryAddress,
                feeTreasury: feeTreasuryAddress,
                feePercentage,
            }: TaskParams,
            { ethers, network, run, upgrades }
        ) => {
            if (!ethers.isAddress(owningTreasuryAddress)) {
                throw new Error("Invalid owning treasury address");
            }
            if (!ethers.isAddress(feeTreasuryAddress)) {
                throw new Error("Invalid fee treasury address");
            }

            const networkName = network.name as Network;
            console.log(`Network name: ${networkName}`);
            if (!isLocalNetwork(networkName)) {
                await run(TASK_CLEAN);
            }
            await run(TASK_COMPILE);

            const deployer = await getSigner(ethers, network.provider, network.config.from);
            const HeroToken = await ethers.getContractFactory("HeroToken", deployer);

            const heroToken = await upgrades.deployProxy(HeroToken, [
                owningTreasuryAddress,
                feeTreasuryAddress,
                feePercentage,
            ]);
            await heroToken.waitForDeployment();

            const heroTokenAddress = await heroToken.getAddress();
            console.log(`HeroToken Proxy deployed at ${heroTokenAddress}`);

            const implementationAddress =
                await upgrades.erc1967.getImplementationAddress(heroTokenAddress);
            console.log(`HeroToken Implementation deployed at ${implementationAddress}`);

            const adminAddress = await upgrades.erc1967.getAdminAddress(heroTokenAddress);
            console.log(`HeroToken Admin deployed at ${adminAddress}`);
        }
    );
