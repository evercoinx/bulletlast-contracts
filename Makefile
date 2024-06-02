# Binaries
BIN_HARDHAT := ./node_modules/.bin/hardhat
BIN_ECHIDNA := echidna
BIN_MYTH := myth

# Configs
CONFIG_ECHIDNA := echidna.config.yaml
CONFIG_SOLC := solc.json

# Networks
NETWORK_HARDHAT := hardhat
NETWORK_LOCALHOST := localhost
NETWORK_BSC_TESTNET := bscTestnet
NETWORK_SEPOLIA := sepolia
NETWORK_BSC_MAINNET := bscMainnet
NETWORK_ETHEREUM := ethereum

# Hardhat contract addresses
HARDHAT_HERO_TOKEN := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
HARDHAT_HERO_VESTING_MANAGER := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
HARDHAT_OWNING_TREASURY := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
HARDHAT_FEE_TREASURY := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Localhost contract addresses
LOCALHOST_HERO_TOKEN := 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
LOCALHOST_HERO_VESTING_MANAGER := 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
LOCALHOST_OWNING_TREASURY := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
LOCALHOST_FEE_TREASURY := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# BSC Testnet contract addresses
BSC_TESTNET_HERO_TOKEN := 0xEb8A47b2C73EeE6D2E2ff55e8eb0745C4Da7e220
BSC_TESTNET_HERO_VESTING_MANAGER := 0x37f69C21DdeDb0fB3Bd9a7C3B2d45857aC1d29d1
BSC_TESTNET_OWNING_TREASURY := 0xB3CE464fFc5547b0cd8114307a5fa46c871A769F
BSC_TESTNET_FEE_TREASURY := 0xB3CE464fFc5547b0cd8114307a5fa46c871A769F
BSC_TESTNET_MULTISIG := 

# BSC Mainnet contract addresses
BSC_MAINNET_HERO_TOKEN := 
BSC_MAINNET_HERO_VESTING_MANAGER := 
BSC_MAINNET_OWNING_TREASURY := 
BSC_MAINNET_FEE_TREASURY :=
BSC_MAINNET_MULTISIG := 

# Contract paths
CONTRACT_PATH_HERO_TOKEN := contracts/HeroToken.sol
CONTRACT_PATH_HERO_VESTING_MANAGER := contracts/HeroVestingManager.sol

# Contract data
HERO_TOKEN_FEE_PERCENTAGE := 0

all: hardhat

hardhat: deploy-herotoken-hardhat deploy-herovestingmanager-hardhat

localhost: deploy-herotoken-localhost deploy-herovestingmanager-localhost

# Deploy the HeroToken contract
deploy-herotoken-hardhat:
	$(BIN_HARDHAT) deploy:hero-token --network $(NETWORK_HARDHAT) --owning-treasury $(HARDHAT_OWNING_TREASURY) --fee-treasury $(HARDHAT_FEE_TREASURY) --fee-percentage $(HERO_TOKEN_FEE_PERCENTAGE)
deploy-herotoken-localhost:
	$(BIN_HARDHAT) deploy:hero-token --network $(NETWORK_LOCALHOST) --owning-treasury $(LOCALHOST_OWNING_TREASURY) --fee-treasury $(LOCALHOST_FEE_TREASURY) --fee-percentage $(HERO_TOKEN_FEE_PERCENTAGE)
deploy-herotoken-bsctestnet:
	$(BIN_HARDHAT) deploy:hero-token --network $(NETWORK_BSC_TESTNET) --owning-treasury $(BSC_TESTNET_OWNING_TREASURY) --fee-treasury $(BSC_TESTNET_FEE_TREASURY) --fee-percentage $(HERO_TOKEN_FEE_PERCENTAGE)
deploy-herotoken-bscmainnet:
	$(BIN_HARDHAT) deploy:hero-token --network $(NETWORK_BSC_MAINNET) --owning-treasury $(BSC_MAINNET_OWNING_TREASURY) --fee-treasury $(BSC_MAINNET_FEE_TREASURY) --fee-percentage $(HERO_TOKEN_FEE_PERCENTAGE)

# Deploy the HeroVestingManager contract
deploy-herovestingmanager-hardhat:
	$(BIN_HARDHAT) deploy:hero-vesting-manager --network $(NETWORK_HARDHAT) --vesting-token $(HARDHAT_HERO_TOKEN)
deploy-herovestingmanager-localhost:
	$(BIN_HARDHAT) deploy:hero-vesting-manager --network $(NETWORK_LOCALHOST) --vesting-token $(LOCALHOST_HERO_TOKEN)
deploy-herovestingmanager-bsctestnet:
	$(BIN_HARDHAT) deploy:hero-vesting-manager --network $(NETWORK_BSC_TESTNET) --vesting-token $(BSC_TESTNET_HERO_TOKEN)
deploy-herovestingmanager-bscmainnet:
	$(BIN_HARDHAT) deploy:hero-vesting-manager --network $(NETWORK_BSC_MAINNET) --vesting-token $(BSC_MAINNET_HERO_TOKEN)

# Upgrade the HeroToken contract
upgradecontract-herotoken-localhost:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_LOCALHOST) --name HeroToken --contract $(LOCALHOST_HERO_TOKEN)
upgradecontract-herotoken-bsctestnet:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_BSC_TESTNET) --name HeroToken --contract $(BSC_TESTNET_HERO_TOKEN)
upgradecontract-herotoken-bscmainnet:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_BSC_MAINNET) --name HeroToken --contract $(BSC_MAINNET_HERO_TOKEN)

# Upgrade the HeroVestingManager contract
upgradecontract-herovestingmanager-localhost:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_LOCALHOST) --name HeroVestingManager --contract $(LOCALHOST_HERO_VESTING_MANAGER)
upgradecontract-herovestingmanager-bsctestnet:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_BSC_TESTNET) --name HeroVestingManager --contract $(BSC_TESTNET_HERO_VESTING_MANAGER)
upgradecontract-herovestingmanager-bscmainnet:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_BSC_MAINNET) --name HeroVestingManager --contract $(BSC_MAINNET_HERO_VESTING_MANAGER)

# Verify the HeroToken contract
verifycontract-herotoken-bsctestnet:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_BSC_TESTNET) --contract $(BSC_TESTNET_HERO_TOKEN)
verifycontract-herotoken-bscmainnet:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_BSC_MAINNET) --contract $(BSC_MAINNET_HERO_TOKEN)

# Verify the HeroVestingManager contract
verifycontract-herovestingmanager-bsctestnet:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_BSC_TESTNET) --contract $(BSC_TESTNET_HERO_VESTING_MANAGER)
verifycontract-herovestingmanager-bscmainnet:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_BSC_MAINNET) --contract $(BSC_MAINNET_HERO_VESTING_MANAGER)

# Transfer proxy admin's ownership
transferownership-proxyadmin-bsctestnet:
	$(BIN_HARDHAT) transfer-ownership:proxy-admin --network $(NETWORK_BSC_TESTNET) --new-owner $(BSC_TESTNET_MULTISIG)
transferownership-proxyadmin-bscmainnet:
	$(BIN_HARDHAT) transfer-ownership:proxy-admin --network $(NETWORK_BSC_MAINNET) --new-owner $(BSC_MAINNET_MULTISIG)

# Analyze contracts with mythril
analyze-mytrhil-herotoken:
	$(BIN_MYTH) analyze $(CONTRACT_PATH_HERO_TOKEN) --solc-json $(CONFIG_SOLC)
analyze-mytrhil-herovestingmanager:
	$(BIN_MYTH) analyze $(CONTRACT_PATH_HERO_VESTING_MANAGER) --solc-json $(CONFIG_SOLC)
