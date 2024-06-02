export enum Provider {
    Alchemy = "alchemy",
    Infura = "infura",
}

export enum Network {
    Hardhat = "hardhat",
    Localhost = "localhost",
    BSCTestnet = "bscTestnet",
    Sepolia = "sepolia",
    BSCMainnet = "bscMainnet",
    Ethereum = "ethereum",
    EthereumAlt = "mainnet",
}

export function getProviderUrl(
    network: Network,
    provider?: Provider,
    apiKey?: string
): string | undefined {
    if (network === Network.Hardhat) {
        return undefined;
    }

    if (network === Network.Localhost) {
        return "http://127.0.0.1:8545";
    }

    if ([Network.BSCTestnet, Network.BSCMainnet].includes(network)) {
        const urls: Record<string, string | undefined> = {
            [Network.BSCTestnet]: "https://data-seed-prebsc-1-s1.binance.org:8545",
            [Network.BSCMainnet]: "https://bsc-dataseed1.binance.org",
        };
        return urls[network];
    }

    const apiVersions: Record<Provider, number> = {
        [Provider.Alchemy]: 2,
        [Provider.Infura]: 3,
    };

    const urls: Record<string, Record<Provider, string | undefined>> = {
        [Network.Sepolia]: {
            [Provider.Alchemy]: "https://eth-sepolia.g.alchemy.com",
            [Provider.Infura]: "https://sepolia.infura.io",
        },
        [Network.Ethereum]: {
            [Provider.Alchemy]: "https://eth-mainnet.g.alchemy.com",
            [Provider.Infura]: "https://mainnet.infura.io",
        },
        [Network.EthereumAlt]: {
            [Provider.Alchemy]: "https://eth-mainnet.g.alchemy.com",
            [Provider.Infura]: "https://mainnet.infura.io",
        },
    };

    return provider && `${urls[network][provider]}/v${apiVersions[provider]}/${apiKey}`;
}

export function isLocalNetwork(network: Network): boolean {
    return [Network.Hardhat, Network.Localhost].includes(network);
}

export function isTestNetwork(network: Network): boolean {
    return [Network.BSCTestnet].includes(network);
}

export function isMainNetwork(network: Network): boolean {
    return [Network.BSCMainnet].includes(network);
}
