const { Network } = require("./utils/network");

module.exports = {
    configureYulOptimizer: true,
    network: Network.Hardhat,
    skipFiles: ["contracts/BulletLastToken.sol", "interfaces/", "libraries/", "mocks/"],
};
