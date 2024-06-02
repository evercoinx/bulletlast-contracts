import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { task, types } from "hardhat/config";
import { getSigner } from "../utils/account";
import { isLocalNetwork, Network } from "../utils/network";

interface TaskParams {
    vestingToken: string;
}

task("deploy:hero-vesting-manager")
    .setDescription("Deploy the HeroVestingManager contract")
    .addParam<string>("vestingToken", "Vesting token address", undefined, types.string)
    .setAction(
        async (
            { vestingToken: vestingTokenAddress }: TaskParams,
            { ethers, network, run, upgrades }
        ) => {
            if (!ethers.isAddress(vestingTokenAddress)) {
                throw new Error("Invalid vesting token address");
            }

            const networkName = network.name as Network;
            console.log(`Network name: ${networkName}`);
            if (!isLocalNetwork(networkName)) {
                await run(TASK_CLEAN);
            }
            await run(TASK_COMPILE);

            const deployer = await getSigner(ethers, network.provider, network.config.from);
            const HeroVestingManager = await ethers.getContractFactory(
                "HeroVestingManager",
                deployer
            );

            const vestingManager = await upgrades.deployProxy(HeroVestingManager, [
                vestingTokenAddress,
            ]);
            await vestingManager.waitForDeployment();

            const vestingManagerAddress = await vestingManager.getAddress();
            console.log(`HeroVestingManager Proxy deployed at ${vestingManagerAddress}`);

            const implementationAddress =
                await upgrades.erc1967.getImplementationAddress(vestingManagerAddress);
            console.log(`HeroVestingManager Implementation deployed at ${implementationAddress}`);

            const adminAddress = await upgrades.erc1967.getAdminAddress(vestingManagerAddress);
            console.log(`HeroVestingManager Admin deployed at ${adminAddress}`);
        }
    );
