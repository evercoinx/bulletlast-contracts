import { ethers as ethersType } from "ethers";
import { EIP1193Provider, HardhatEthersHelpers } from "hardhat/types";

type HardhatEthers = typeof ethersType & HardhatEthersHelpers;

export async function getSigner(
    ethers: HardhatEthers,
    ethereum: EIP1193Provider,
    address?: string
) {
    const provider = new ethers.BrowserProvider(ethereum);
    return await provider.getSigner(address);
}

export function generateRandomAddress(ethers: HardhatEthers) {
    const privateKey = `0x${Buffer.from(ethers.randomBytes(32)).toString("hex")}`;
    return new ethers.Wallet(privateKey).address;
}

interface VersionedAddress {
    address: string;
    version: string;
}

export function parseVersionedAddress(
    ethers: HardhatEthers,
    versionedAddress: string,
    contractName: string
): VersionedAddress {
    const [address, version, ...rest] = versionedAddress.split(":");
    if (rest.length > 0 || !address || !version) {
        throw new Error(
            `Invalid versioned address format for ${contractName} contract: ${versionedAddress}`
        );
    }

    if (!ethers.isAddress(address)) {
        throw new Error(`Invalid ${contractName} address`);
    }

    return {
        address,
        version,
    };
}
