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
HARDHAT_BULLET_LAST_PRESALE := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
HARDHAT_BULLET_LAST_TOKEN := 0x5FbDB2315678afecb367f032d93F642f64180aa3
HARDHAT_ETHER_PRICE_FEED := 0x5FbDB2315678afecb367f032d93F642f64180aa3
HARDHAT_USDT_TOKEN := 0x5FbDB2315678afecb367f032d93F642f64180aa3
HARDHAT_TREASURY := 0x5FbDB2315678afecb367f032d93F642f64180aa3

# Localhost contract addresses
LOCALHOST_BULLET_LAST_PRESALE := 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
LOCALHOST_BULLET_LAST_TOKEN := 0x5FbDB2315678afecb367f032d93F642f64180aa3
LOCALHOST_ETHER_PRICE_FEED := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
LOCALHOST_USDT_TOKEN := 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
LOCALHOST_TREASURY := 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

# Sepolia testnet contract addresses
SEPOLIA_BULLET_LAST_PRESALE := 0x998E69C9f276A49905f081C7cDCBa448C7d16523
SEPOLIA_BULLET_LAST_TOKEN := 0x04D66AD32542453fF82C1476b0c5A922aB7C9bcF
SEPOLIA_ETHER_PRICE_FEED := 0x694AA1769357215DE4FAC081bf1f309aDC325306
SEPOLIA_USDT_TOKEN := 0x6b28Cd1378E694AE299940F6B011aD40ce925A8A
SEPOLIA_TREASURY := 0x58Dd2a0F95E346b9b891E0ad23E55B892EE803d7

# Ethereum mainnet contract addresses
ETHEREUM_BULLET_LAST_PRESALE := 
ETHEREUM_BULLET_LAST_TOKEN :=
ETHEREUM_ETHER_PRICE_FEED :=
ETHEREUM_USDT_TOKEN :=
ETHEREUM_TREASURY :=

# Contract paths
CONTRACT_PATH_BULLET_LAST_PRESALE := contracts/BulletLastPresale.sol

# Contract data
SEPOLIA_BULLET_LAST_PRESALE_VESTING_DURATION := 21600
ETHEREUM_BULLET_LAST_PRESALE_VESTING_DURATION := 2592000
SEPOLIA_BULLET_LAST_PRESALE_START_TIME := 0
ETHEREUM_BULLET_LAST_PRESALE_START_TIME := 0
SEPOLIA_BULLET_LAST_PRESALE_ROUND_DURATION := 21600
ETHEREUM_BULLET_LAST_PRESALE_ROUND_DURATION := 259200

all: hardhat

hardhat: deploy-bulletlasttoken-hardhat deploy-bulletlastpresale-hardhat

localhost: deploy-bulletlasttoken-localhost deploy-bulletlastpresale-localhost initialize-bulletlastpresale-localhost

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

# Verify the BulletLastToken contract
verifycontract-bulletlasttoken-sepolia:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_SEPOLIA) --contract $(SEPOLIA_BULLET_LAST_TOKEN) $(SEPOLIA_TREASURY)

# Verify the USDT contract
verifycontract-usdttoken-sepolia:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_SEPOLIA) --contract $(SEPOLIA_USDT_TOKEN) 1000000000000

# Verify the BulletLastPresale contract
verifycontract-bulletlastpresale-sepolia:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_SEPOLIA) --contract $(SEPOLIA_BULLET_LAST_PRESALE)
verifycontract-bulletlastpresale-ethereum:
	$(BIN_HARDHAT) verify-contract --network $(NETWORK_ETHEREUM) --contract $(ETHEREUM_BULLET_LAST_PRESALE)

# Initialize the BulletLastPresale contract
initialize-bulletlastpresale-localhost:
	$(BIN_HARDHAT) initialize:bullet-last-presale --network $(NETWORK_LOCALHOST) --bullet-last-presale $(LOCALHOST_BULLET_LAST_PRESALE) --bullet-last-token $(LOCALHOST_BULLET_LAST_TOKEN) --treasury $(LOCALHOST_TREASURY) --start-time $(SEPOLIA_BULLET_LAST_PRESALE_START_TIME) --round-duration $(SEPOLIA_BULLET_LAST_PRESALE_ROUND_DURATION)
initialize-bulletlastpresale-sepolia:
	$(BIN_HARDHAT) initialize:bullet-last-presale --network $(NETWORK_SEPOLIA) --bullet-last-presale $(SEPOLIA_BULLET_LAST_PRESALE) --bullet-last-token $(SEPOLIA_BULLET_LAST_TOKEN) --treasury $(SEPOLIA_TREASURY) --start-time $(SEPOLIA_BULLET_LAST_PRESALE_START_TIME) --round-duration $(SEPOLIA_BULLET_LAST_PRESALE_ROUND_DURATION)
initialize-bulletlastpresale-ethereum:
	$(BIN_HARDHAT) initialize:bullet-last-presale --network $(NETWORK_ETHEREUM) --bullet-last-presale $(ETHEREUM_BULLET_LAST_PRESALE) --bullet-last-token $(ETHEREUM_BULLET_LAST_TOKEN) --treasury $(ETHEREUM_TREASURY) --start-time $(ETHEREUM_BULLET_LAST_PRESALE_START_TIME) --round-duration $(ETHEREUM_BULLET_LAST_PRESALE_ROUND_DURATION)

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
