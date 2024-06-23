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
NETWORK_SEPOLIA := sepolia
NETWORK_ETHEREUM := ethereum

# Hardhat contract addresses
HARDHAT_BULLET_LAST_TOKEN := 0x5FbDB2315678afecb367f032d93F642f64180aa3
HARDHAT_BULLET_LAST_PRESALE := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
HARDHAT_ETHER_PRICE_FEED := 0x5FbDB2315678afecb367f032d93F642f64180aa3
HARDHAT_TREASURY := 0x5FbDB2315678afecb367f032d93F642f64180aa3
HARDHAT_USDT_TOKEN := 0x5FbDB2315678afecb367f032d93F642f64180aa3

# Localhost contract addresses
LOCALHOST_BULLET_LAST_PRESALE := 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
LOCALHOST_BULLET_LAST_TOKEN := 0x5FbDB2315678afecb367f032d93F642f64180aa3
LOCALHOST_ETHER_PRICE_FEED := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
LOCALHOST_ROUND_MANAGER := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
LOCALHOST_TREASURY := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
LOCALHOST_USDT_TOKEN := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

# Sepolia testnet contract addresses
SEPOLIA_BULLET_LAST_PRESALE := 0xB9cF6852E4Cc82003D9B6828aff69FeD439F12DB
SEPOLIA_BULLET_LAST_TOKEN := 0x1B3d396Cb40595d61b38B9aDCDf09D5503894c8f
SEPOLIA_ETHER_PRICE_FEED := 0x694AA1769357215DE4FAC081bf1f309aDC325306
SEPOLIA_ROUND_MANAGER := 0x36a16bfbbd34fdf8dc330341576eda4a56f2add8
SEPOLIA_TREASURY := 0x58Dd2a0F95E346b9b891E0ad23E55B892EE803d7
SEPOLIA_USDT_TOKEN := 0x43c8faF02c9316a2960eA4E8B28e63a2b7432029

# Ethereum mainnet contract addresses
ETHEREUM_BULLET_LAST_PRESALE := 
ETHEREUM_BULLET_LAST_TOKEN :=
ETHEREUM_ETHER_PRICE_FEED :=
ETHEREUM_ROUND_MANAGER := 
ETHEREUM_USDT_TOKEN :=
ETHEREUM_TREASURY :=

# Contract paths
CONTRACT_PATH_BULLET_LAST_PRESALE := contracts/BulletLastPresale.sol

# Contract data
SEPOLIA_BULLET_LAST_PRESALE_VESTING_DURATION := 2592000
ETHEREUM_BULLET_LAST_PRESALE_VESTING_DURATION := 2592000
SEPOLIA_BULLET_LAST_PRESALE_START_TIME := 0
ETHEREUM_BULLET_LAST_PRESALE_START_TIME := 0
SEPOLIA_BULLET_LAST_PRESALE_ROUND_DURATION := 259200
ETHEREUM_BULLET_LAST_PRESALE_ROUND_DURATION := 259200

all: hardhat

hardhat: deploy-bulletlasttokenmock-hardhat deploy-usdttokenmock-hardhat deploy-bulletlastpresale-hardhat

localhost: deploy-bulletlasttokenmock-localhost deploy-usdttokenmock-localhost deploy-bulletlastpresale-localhost

# Deploy the BulletLastToken contract
deploy-bulletlasttokenmock-hardhat:
	$(BIN_HARDHAT) deploy:bullet-last-token-mock --network $(NETWORK_HARDHAT)
deploy-bulletlasttokenmock-localhost:
	$(BIN_HARDHAT) deploy:bullet-last-token-mock --network $(NETWORK_LOCALHOST)
deploy-bulletlasttokenmock-sepolia:
	$(BIN_HARDHAT) deploy:bullet-last-token-mock --network $(NETWORK_SEPOLIA)

# Deploy the USDTToken contract
deploy-usdttokenmock-hardhat:
	$(BIN_HARDHAT) deploy:usdt-token-mock --network $(NETWORK_HARDHAT)
deploy-usdttokenmock-localhost:
	$(BIN_HARDHAT) deploy:usdt-token-mock --network $(NETWORK_LOCALHOST)
deploy-usdttokenmock-sepolia:
	$(BIN_HARDHAT) deploy:usdt-token-mock --network $(NETWORK_SEPOLIA)

# Deploy the BulletLastPresale contract
deploy-bulletlastpresale-hardhat:
	$(BIN_HARDHAT) deploy:bullet-last-presale --network $(NETWORK_HARDHAT) --sale-token $(HARDHAT_BULLET_LAST_TOKEN) --ether-price-feed $(HARDHAT_ETHER_PRICE_FEED) --usdt-token $(HARDHAT_USDT_TOKEN) --treasury $(HARDHAT_TREASURY) --vesting-duration $(SEPOLIA_BULLET_LAST_PRESALE_VESTING_DURATION)
deploy-bulletlastpresale-localhost:
	$(BIN_HARDHAT) deploy:bullet-last-presale --network $(NETWORK_LOCALHOST) --sale-token $(LOCALHOST_BULLET_LAST_TOKEN) --ether-price-feed $(LOCALHOST_ETHER_PRICE_FEED) --usdt-token $(LOCALHOST_USDT_TOKEN) --treasury $(LOCALHOST_TREASURY) --vesting-duration $(SEPOLIA_BULLET_LAST_PRESALE_VESTING_DURATION)
deploy-bulletlastpresale-sepolia:
	$(BIN_HARDHAT) deploy:bullet-last-presale --network $(NETWORK_SEPOLIA) --sale-token $(SEPOLIA_BULLET_LAST_TOKEN) --ether-price-feed $(SEPOLIA_ETHER_PRICE_FEED) --usdt-token $(SEPOLIA_USDT_TOKEN) --treasury $(SEPOLIA_TREASURY) --vesting-duration $(SEPOLIA_BULLET_LAST_PRESALE_VESTING_DURATION)
deploy-bulletlastpresale-ethereum:
	$(BIN_HARDHAT) deploy:bullet-last-presale --network $(NETWORK_ETHEREUM) --sale-token $(ETHEREUM_BULLET_LAST_TOKEN) --ether-price-feed $(ETHEREUM_ETHER_PRICE_FEED) --usdt-token $(ETHEREUM_USDT_TOKEN) --treasury $(ETHEREUM_TREASURY) --vesting-duration $(ETHEREUM_BULLET_LAST_PRESALE_VESTING_DURATION)

# Deploy the BulletLastPresale contract's implementation
deployimplementation-bulletlastpresale-localhost:
	$(BIN_HARDHAT) deploy-implementation --network $(NETWORK_LOCALHOST) --name BulletLastPresale
deployimplementation-bulletlastpresale-sepolia:
	$(BIN_HARDHAT) deploy-implementation --network $(NETWORK_SEPOLIA) --name BulletLastPresale
deployimplementation-bulletlastpresale-ethereum:
	$(BIN_HARDHAT) deploy-implementation --network $(NETWORK_ETHEREUM) --name BulletLastPresale

# Verify the BulletLastToken contract
verifycontract-bulletlasttokenmock-sepolia:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_SEPOLIA) --contract $(SEPOLIA_BULLET_LAST_TOKEN) "$(SEPOLIA_TREASURY)"

# Verify the USDT contract
verifycontract-usdttokenmock-sepolia:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_SEPOLIA) --contract $(SEPOLIA_USDT_TOKEN) "1000000000000000"

# Verify the BulletLastPresale contract
verifycontract-bulletlastpresale-sepolia:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_SEPOLIA) --contract $(SEPOLIA_BULLET_LAST_PRESALE)
verifycontract-bulletlastpresale-ethereum:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_ETHEREUM) --contract $(ETHEREUM_BULLET_LAST_PRESALE)

# Initialize the BulletLastPresale contract
initialize-bulletlastpresale-localhost:
	$(BIN_HARDHAT) initialize:bullet-last-presale --network $(NETWORK_LOCALHOST) --bullet-last-presale $(LOCALHOST_BULLET_LAST_PRESALE) --bullet-last-token $(LOCALHOST_BULLET_LAST_TOKEN) --treasury $(LOCALHOST_TREASURY) --start-time $(SEPOLIA_BULLET_LAST_PRESALE_START_TIME) --round-duration $(SEPOLIA_BULLET_LAST_PRESALE_ROUND_DURATION) --round-manager $(LOCALHOST_ROUND_MANAGER)
initialize-bulletlastpresale-sepolia:
	$(BIN_HARDHAT) initialize:bullet-last-presale --network $(NETWORK_SEPOLIA) --bullet-last-presale $(SEPOLIA_BULLET_LAST_PRESALE) --bullet-last-token $(SEPOLIA_BULLET_LAST_TOKEN) --treasury $(SEPOLIA_TREASURY) --start-time $(SEPOLIA_BULLET_LAST_PRESALE_START_TIME) --round-duration $(SEPOLIA_BULLET_LAST_PRESALE_ROUND_DURATION) --round-manager $(SEPOLIA_ROUND_MANAGER)
initialize-bulletlastpresale-ethereum:
	$(BIN_HARDHAT) initialize:bullet-last-presale --network $(NETWORK_ETHEREUM) --bullet-last-presale $(ETHEREUM_BULLET_LAST_PRESALE) --bullet-last-token $(ETHEREUM_BULLET_LAST_TOKEN) --treasury $(ETHEREUM_TREASURY) --start-time $(ETHEREUM_BULLET_LAST_PRESALE_START_TIME) --round-duration $(ETHEREUM_BULLET_LAST_PRESALE_ROUND_DURATION) --round-manager $(ETHEREUM_ROUND_MANAGER)

# Upgrade the BulletLastPresale contract
upgradecontract-bulletlastpresale-localhost:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_LOCALHOST) --name BulletLastPresale --contract $(LOCALHOST_BULLET_LAST_PRESALE)
upgradecontract-bulletlastpresale-sepolia:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_SEPOLIA) --name BulletLastPresale --contract $(SEPOLIA_BULLET_LAST_PRESALE)
upgradecontract-bulletlastpresale-ethereum:
	$(BIN_HARDHAT) upgrade-contract --network $(NETWORK_ETHEREUM) --name BulletLastPresale --contract $(ETHEREUM_BULLET_LAST_PRESALE)

# Transfer proxy admin's ownership
transferownership-proxyadmin-sepolia:
	$(BIN_HARDHAT) transfer-ownership:proxy-admin --network $(NETWORK_SEPOLIA) --new-owner $(SEPOLIA_MULTISIG)
transferownership-proxyadmin-ethereum:
	$(BIN_HARDHAT) transfer-ownership:proxy-admin --network $(NETWORK_ETHEREUM) --new-owner $(ETHEREUM_MULTISIG)

# Analyze contracts with mythril
analyze-mytrhil-bulletlastpresale:
	$(BIN_MYTH) analyze $(CONTRACT_PATH_BULLET_LAST_PRESALE) --solc-json $(CONFIG_SOLC)
