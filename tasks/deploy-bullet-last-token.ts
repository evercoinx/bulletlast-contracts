import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { task } from "hardhat/config";
import { getSigner } from "../utils/account";
import { isLocalNetwork, Network } from "../utils/network";

task("deploy:bullet-last-token")
    .setDescription("Deploy the BulletLastToken contract")
    .setAction(async (_, { ethers, network, run }) => {
        const networkName = network.name as Network;
        console.log(`Network name: ${networkName}`);
        if (!isLocalNetwork(networkName)) {
            await run(TASK_CLEAN);
        }
        await run(TASK_COMPILE);

        const deployer = await getSigner(ethers, network.provider, network.config.from);
        const BulletLastToken = await ethers.getContractFactory("BulletLastToken", deployer);

        const bulletLastToken = await BulletLastToken.deploy(deployer.address);
        await bulletLastToken.waitForDeployment();

        const bulletLastTokenAddress = await bulletLastToken.getAddress();
        console.log(`BulletLastToken deployed at ${bulletLastTokenAddress}`);
    });
