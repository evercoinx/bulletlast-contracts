const { Network } = require("./utils/network");

module.exports = {
    configureYulOptimizer: true,
    network: Network.Hardhat,
    skipFiles: ["interfaces/", "libraries/", "mocks/"],
};
