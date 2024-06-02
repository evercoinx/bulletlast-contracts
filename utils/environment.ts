import Joi from "joi";
import { Provider } from "./network";

interface EnvironmentSchema {
    API_PROVIDER: Provider;
    SEPOLIA_API_KEY: string;
    ETHEREUM_API_KEY: string;
    BSCSCAN_API_KEY: string;
    ETHERSCAN_API_KEY: string;
    OZ_DEFENDER_API_KEY: string;
    OZ_DEFENDER_API_SECRET: string;
    COINMARKETCAP_API_KEY: string;
    GAS_REPORTER_NETWORK: string;
    DEPLOYER_MNEMONIC: string;
    DEPLOYER_PASSPHRASE: string;
    DEPLOYER_ADDRESS: string;
}

const SCANNER_API_REGEX = /^[0-9A-Za-z_-]{32}$/;
const MNEMONIC_REGEX = /^([a-z ]+){12,24}$/;
const ADDRESS_REGEX = /^0x[0-9A-Fa-f]{40}$/;

export function extractEnvironmentVariables(): EnvironmentSchema {
    const envSchema = Joi.object()
        .keys({
            API_PROVIDER: Joi.string()
                .optional()
                .valid("alchemy", "infura")
                .default("alchemy")
                .default("API provider name"),
            SEPOLIA_API_KEY: Joi.string()
                .required()
                .regex(SCANNER_API_REGEX)
                .description("API key for Sepolia"),
            ETHEREUM_API_KEY: Joi.string()
                .required()
                .regex(SCANNER_API_REGEX)
                .description("API key for Ethereum"),
            BSCSCAN_API_KEY: Joi.string()
                .required()
                .length(34)
                .alphanum()
                .description("API key for BSCScan"),
            ETHERSCAN_API_KEY: Joi.string()
                .required()
                .length(34)
                .alphanum()
                .description("API key for Etherscan"),
            OZ_DEFENDER_API_KEY: Joi.string()
                .required()
                .length(32)
                .alphanum()
                .description("API key for OpenZeppelin Defender"),
            OZ_DEFENDER_API_SECRET: Joi.string()
                .required()
                .length(64)
                .alphanum()
                .description("API secret key for OpenZeppelin Defender"),
            COINMARKETCAP_API_KEY: Joi.string()
                .optional()
                .allow("")
                .uuid({ version: "uuidv4" })
                .description("API key for Coinmarketcap"),
            GAS_REPORTER_NETWORK: Joi.string()
                .optional()
                .allow("bsc", "ethereum")
                .default("bsc")
                .description("Gas reporter network"),
            DEPLOYER_MNEMONIC: Joi.string()
                .optional()
                .default("test test test test test test test test test test test junk")
                .regex(MNEMONIC_REGEX)
                .description("Mnemonic phrase of deployer account"),
            DEPLOYER_PASSPHRASE: Joi.string()
                .optional()
                .allow("")
                .description("Passphrase of deployer account"),
            DEPLOYER_ADDRESS: Joi.string()
                .required()
                .regex(ADDRESS_REGEX)
                .description("Address of deployer account"),
        })
        .unknown() as Joi.ObjectSchema<EnvironmentSchema>;

    const { value: envVars, error } = envSchema
        .prefs({
            errors: {
                label: "key",
            },
        })
        .validate(process.env);
    if (error) {
        throw new Error(error.annotate());
    }
    return envVars;
}
