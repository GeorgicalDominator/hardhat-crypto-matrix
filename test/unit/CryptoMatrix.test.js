const { assert, expect } = require("chai")
const { network, deployments, ethers } = require("hardhat")

describe("CryptoMatrix", () => {
    let cryptoMatrix, mockV3Aggregator, deployer, accounts

    beforeEach(async () => {
        accounts = await ethers.getSigners()
        deployer = accounts[0]
        await deployments.fixture(["all"])
        cryptoMatrix = await ethers.getContract("CryptoMatrix")
        await cryptoMatrix.setPriceForLevel(1, 1000)
        await cryptoMatrix.setLevelState(1, true)
        await cryptoMatrix.whitelistOpener(false)
    })

    describe("game", () => {
        it("should correctly join to the game", async () => {
            const cryptoMatrixConnectedContract = await cryptoMatrix.connect(accounts[1])
            const resp1 = await cryptoMatrixConnectedContract.joinGame(1, {value:ethers.utils.parseEther("2")})
            resp1.wait(1)
            assert(await cryptoMatrixConnectedContract.getAddressAndLevelToParticipation(accounts[1].address, 1))
        }) 

        it("should revert if you try to join second time the same level", async () => {
            const cryptoMatrixConnectedContract = await cryptoMatrix.connect(accounts[1])
            const resp1 = await cryptoMatrixConnectedContract.joinGame(1, {value:ethers.utils.parseEther("2")})
            resp1.wait(1)
            await expect(cryptoMatrixConnectedContract.joinGame(1, {value:ethers.utils.parseEther("2")})).to.be.revertedWith("CryptoMatrix__AlreadyOnLevel")
            
        }) 

        it("should make profit", async () => {
            const firsBalance = await accounts[1].getBalance()

            for (let i = 1; i < 20; i++) {
                const cryptoMatrixConnectedContract = await cryptoMatrix.connect(accounts[i])
                await cryptoMatrixConnectedContract.joinGame(1, {value:ethers.utils.parseEther("10")})
            }
            
            const secondBalance = await accounts[1].getBalance()
            await expect(secondBalance.gt(firsBalance)).to.be.true
        }) 

        it("should be allowed only for whitelist", async () => {
            await cryptoMatrix.whitelistOpener(true)
            await cryptoMatrix.setWhitelistMemberState(accounts[1].address, true)
            const cryptoMatrixConnectedContract = await cryptoMatrix.connect(accounts[1])
            const cryptoMatrixConnectedContract2 = await cryptoMatrix.connect(accounts[2])
            assert(await cryptoMatrixConnectedContract.joinGame(1, {value:ethers.utils.parseEther("10")}))
            await expect(cryptoMatrixConnectedContract2.joinGame(1, {value:ethers.utils.parseEther("10")})).to.be.revertedWith("CryptoMatrix__YouNotInWhiteList")
        })

        it("should make profit for leader who leads referals", async () => {
            const firsBalance = await accounts[1].getBalance()
            const leaderAddress = accounts[1].address
            for (let i = 2; i < 20; i++) {
                const cryptoMatrixConnectedContract = await cryptoMatrix.connect(accounts[i])
                await cryptoMatrixConnectedContract.becomeReferaled(leaderAddress)
                await cryptoMatrixConnectedContract.joinGame(1, {value:ethers.utils.parseEther("10")})
            }

            const secondBalance = await accounts[1].getBalance()
            await expect(secondBalance.gt(firsBalance)).to.be.true
        })

        it("money should correctly withdrawed after game", async () => {
            const firsBalance = await accounts[0].getBalance()
            for (let i = 1; i < 20; i++) {
                const cryptoMatrixConnectedContract = await cryptoMatrix.connect(accounts[i])
                await cryptoMatrixConnectedContract.joinGame(1, {value:ethers.utils.parseEther("10")})
            }
            await cryptoMatrix.withdraw()
            const secondBalance = await accounts[0].getBalance()
            await expect(secondBalance.gt(firsBalance)).to.be.true
        })

    })

})