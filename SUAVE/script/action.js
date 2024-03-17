const { task, experimentalAddHardhatNetworkMessageTraceHook } = require("hardhat/config");
const {SuaveProvider, SuaveWallet, SuaveContract} = require('ethers-suave')
const { ethers, BigNumber } = require('ethers')


task('action')
	.setAction(async function (_, hre) {
        const executionNodeAddress = '0x03493869959c866713c33669ca118e774a30a0e5'
        const suaveAuctionAdd = '0x54a4dDa9CE124774aEaEDb9056fD14f98b55AFFC'
        const suaveAuctionABI = require('../../abis/SuaveAuction.json')

        const rigilUrl = hre.network.config.url;
        const rigilPKA = hre.network.config.accounts[1];
        const rigilPKB = hre.network.config.accounts[2];
        const suaveProvider = new SuaveProvider(rigilUrl, executionNodeAddress)
		const suaveSignerA = new SuaveWallet(rigilPKA, suaveProvider)
		const suaveSignerB = new SuaveWallet(rigilPKB, suaveProvider)
        const AuctionContractA = new SuaveContract(suaveAuctionAdd, suaveAuctionABI, suaveSignerA)
        const AuctionContractB = new SuaveContract(suaveAuctionAdd, suaveAuctionABI, suaveSignerB)

        const pool = '0x030eF8F38E149C7954B481208a2305F9D6B82E8e'
        const poolId = '0xcc8fda3516a2362da0bc1e5a33ccbf8913616bc400cac3d7ae6e0e9dc5097834'
        const blockNumber = 2134116
        const bidAmounts = [
            ethers.utils.parseEther('0.001'),
            ethers.utils.parseEther('0.002')
        ]
        console.log(`🚀 Submitting bids for pool: ${pool} with poolId: ${poolId} at block: ${blockNumber}`)

        console.log(`\t🅰️ Submitting bid for signerA(${suaveSignerA.address}) with bid amount ${bidAmounts[0].toString()}`)
        const resA = await AuctionContractA
            .submitBid
            .sendConfidentialRequest(pool, poolId, blockNumber, bidAmounts[0].toHexString());
        console.log(resA)

        console.log(`\t🅱️ Submitting bid for signerB(${suaveSignerB.address}) with bid amount ${bidAmounts[1].toString()}`)
        const resB = await AuctionContractB
            .submitBid
            .sendConfidentialRequest(pool, poolId, blockNumber, bidAmounts[1].toHexString());
        console.log(resB)

        console.log()

        console.log("👀 Settling the auction")
        // todo: reenable settlement checking - slot param
        let resAuction = await AuctionContractB.settleAuction.sendConfidentialRequest(pool, poolId, blockNumber, 0);
        console.log(resAuction)


        console.log(resAuction.confidentialComputeResult)
        console.log()
        const decoded = AuctionContractA.interface.parseTransaction({
            data: resAuction.confidentialComputeResult
        });
        console.log(decoded)
        
        const types = ['uint64', 'uint256', 'bytes'];
        const encodedParams = ethers.utils.defaultAbiCoder.encode(
            types,
            [decoded.args[0][2], decoded.args[0][4], decoded.args[1]],
        )
        console.log(encodedParams)

        // SWAP 
        const arbRpc = 'https://sepolia-rollup.arbitrum.io/rpc'
        const uniRouter = '0x5bA874E13D2Cf3161F89D1B1d1732D14226dBF16'
        const uniRouterABI = require('../../abis/UniRouterABI.json')

        const provider = new ethers.providers.JsonRpcProvider(arbRpc)
        const walletA = new ethers.Wallet(rigilPKA, provider)
        const walletB = new ethers.Wallet(rigilPKB, provider)

        const RouterContract = new ethers.Contract(uniRouter, uniRouterABI, walletA)

        const res = await RouterContract.swap(
            [
                '0xA47757c742f4177dE4eEA192380127F8B62455F5',
                '0xFDA93151f6146f763D3A80Ddb4C5C7B268469465',
                4000,
                10,
                '0x030eF8F38E149C7954B481208a2305F9D6B82E8e'
            ],
            [
                true,
                '0x29a2241af62c0000',
                4295128740
            ],
            [
                true,
                true,
                false
            ],
            encodedParams,
            { gasLimit: 20000000 }
        )
        console.log(res)
        console.log(await res.wait())



	})
