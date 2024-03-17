const { task } = require("hardhat/config");
const {SuaveProvider, SuaveWallet, SuaveContract} = require('ethers-suave')


task('deploy')
	.addParam('registry')
	.addParam('settlementchainrpc')
	.setAction(async function (taskArgs, hre) {
        const registry = taskArgs.registry
        const settlementChainRpc = taskArgs.settlementchainrpc
        console.log(`Deploying with registry: ${registry} and settlement chain rpc: ${settlementChainRpc}`)
        const rigilUrl = hre.network.config.url;
        const rigilPK = hre.network.config.accounts[0];
        const provider = new hre.ethers.providers.JsonRpcProvider(rigilUrl)
        const wallet = new hre.ethers.Wallet(rigilPK, provider)

        const auctionContract = await hre.ethers.getContractFactory('Auction')
            .then(async (factory) => {
                const oracleContract = await factory.connect(wallet).deploy(registry, settlementChainRpc)
                await oracleContract.deployTransaction.wait()
                return oracleContract
            })
            .catch((err) => {
                console.log(err)
            })
        const executionNodeAddress = '0x03493869959c866713c33669ca118e774a30a0e5'
        const suaveProvider = new SuaveProvider(rigilUrl, executionNodeAddress)
		const suaveSigner = new SuaveWallet(rigilPK, suaveProvider)
		const AuctionContract = new SuaveContract(
			auctionContract.address, 
			auctionContract.interface,
			suaveSigner
		)
        const res = await AuctionContract.confidentialConstructor.sendConfidentialRequest({})
        console.log(res)
	})
