import { task, types } from "hardhat/config";
import { TASK_CLEAN, TASK_COMPILE } from "hardhat/builtin-tasks/task-names";
import { isLocalNetwork, Network } from "../utils/network";

interface TaskParams {
    name: string;
    contract: string;
}

task("upgrade-contract")
    .setDescription("Upgrade a contract")
    .addParam<string>("name", "Contract name", undefined, types.string)
    .addParam<string>("contract", "Contract address", undefined, types.string)
    .setAction(
        async (
            { name: contractName, contract: contractAddress }: TaskParams,
            { ethers, upgrades, network, run }
        ) => {
            if (!ethers.isAddress(contractAddress)) {
                throw new Error("Invalid contract address");
            }

            const networkName = network.name as Network;
            console.log(`Network name: ${networkName}`);

            await run(TASK_CLEAN);
            await run(TASK_COMPILE);

            const adjustedContractName = isLocalNetwork(networkName)
                ? `${contractName}Mock`
                : contractName;
            const ContractFactory = await ethers.getContractFactory(adjustedContractName);

            await upgrades.upgradeProxy(contractAddress, ContractFactory);

            const implementationAddress =
                await upgrades.erc1967.getImplementationAddress(contractAddress);
            console.log(`${contractName} upgraded with implementation ${implementationAddress}`);
        }
    );
