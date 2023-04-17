const { network } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    let bnbUsdPriceFeedAddress
    
    const ethUsdAggregator = await deployments.get("MockV3Aggregator")
    bnbUsdPriceFeedAddress = ethUsdAggregator.address
    
    log("----------------------------------------------------")
    log("Deploying CryptoMatrix and waiting for confirmations...")
    const CryptoMatrix = await deploy("CryptoMatrix", {
        from: deployer,
        args: [bnbUsdPriceFeedAddress],
        log: true,
        // we need to wait if on a live network so we can verify properly
        waitConfirmations: 1,
    })
    log(`CryptoMatrix deployed at ${CryptoMatrix.address}`)
}

module.exports.tags = ["all", "cryptomatrix"]