import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { task } from "hardhat/config";
import { getSigner } from "../utils/account";
import { isLocalNetwork, Network } from "../utils/network";

task("deploy:usdt-token")
    .setDescription("Deploy the USDTToken contract")
    .setAction(async (_, { ethers, network, run }) => {
        const networkName = network.name as Network;
        console.log(`Network name: ${networkName}`);
        if (!isLocalNetwork(networkName)) {
            await run(TASK_CLEAN);
        }
        await run(TASK_COMPILE);

        const deployer = await getSigner(ethers, network.provider, network.config.from);
        const USDTToken = await ethers.getContractFactory("USDTToken", deployer);

        const usdtToken = await USDTToken.deploy(1_000_000n * 10n ** 6n);
        await usdtToken.waitForDeployment();

        const usdtTokenAddress = await usdtToken.getAddress();
        console.log(`USDTToken deployed at ${usdtTokenAddress}`);
    });
