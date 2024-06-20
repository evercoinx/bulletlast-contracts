import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { task } from "hardhat/config";
import { getSigner } from "../utils/account";
import { isLocalNetwork, Network } from "../utils/network";

task("deploy:bullet-last-token-mock")
    .setDescription("Deploy the BulletLastTokenMock contract")
    .setAction(async (_, { ethers, network, run }) => {
        const networkName = network.name as Network;
        console.log(`Network name: ${networkName}`);
        if (!isLocalNetwork(networkName)) {
            await run(TASK_CLEAN);
        }
        await run(TASK_COMPILE);

        const deployer = await getSigner(ethers, network.provider, network.config.from);
        const BulletLastTokenMock = await ethers.getContractFactory(
            "BulletLastTokenMock",
            deployer
        );

        const bulletLastTokenMock = await BulletLastTokenMock.deploy(deployer.address);
        await bulletLastTokenMock.waitForDeployment();

        const bulletLastTokenMockAddress = await bulletLastTokenMock.getAddress();
        console.log(`BulletLastTokenMock deployed at ${bulletLastTokenMockAddress}`);
    });
