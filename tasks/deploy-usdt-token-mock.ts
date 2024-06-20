import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { task } from "hardhat/config";
import { getSigner } from "../utils/account";
import { isLocalNetwork, Network } from "../utils/network";

task("deploy:usdt-token-mock")
    .setDescription("Deploy the USDTTokenMock contract")
    .setAction(async (_, { ethers, network, run }) => {
        const networkName = network.name as Network;
        console.log(`Network name: ${networkName}`);
        if (!isLocalNetwork(networkName)) {
            await run(TASK_CLEAN);
        }
        await run(TASK_COMPILE);

        const deployer = await getSigner(ethers, network.provider, network.config.from);
        const USDTTokenMock = await ethers.getContractFactory("USDTTokenMock", deployer);

        const usdtTokenMock = await USDTTokenMock.deploy(ethers.parseUnits("1000000000", 6));
        await usdtTokenMock.waitForDeployment();

        const usdtTokenMockAddress = await usdtTokenMock.getAddress();
        console.log(`USDTTokenMock deployed at ${usdtTokenMockAddress}`);
    });
