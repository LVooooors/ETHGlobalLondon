const { task, experimentalAddHardhatNetworkMessageTraceHook } = require("hardhat/config");
const {SuaveProvider, SuaveWallet, SuaveContract} = require('ethers-suave')
const { ethers, BigNumber } = require('ethers')


task('action')
	.setAction(async function (_, hre) {
        const executionNodeAddress = '0x03493869959c866713c33669ca118e774a30a0e5'
        const suaveAuctionAdd = '0x689866C124600A4F20AF82245EA00662Fca201DC'
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
        const blockNumber = 6032
        const bidAmounts = [
            ethers.utils.parseEther('0.001'),
            ethers.utils.parseEther('0.007')
        ]
        console.log(`🚀 Submitting bids for pool: ${pool} with poolId: ${poolId} at block: ${blockNumber}`)

        console.log(`\t🅰️ Submitting bid for signerA(${suaveSignerA.address}) with bid amount ${bidAmounts[0].toString()}`)
        const resA = await AuctionContractA
            .submitBid
            .sendConfidentialRequest(pool, poolId, blockNumber, bidAmounts[0].toHexString());
        if (resA.status === 0) {
            console.error('🚨 Submitting bid A failed')
            process.exit(1)
        } else {
            console.log('✅ Submitting bid A suceeded')
        }

        console.log(`\t🅱️ Submitting bid for signerB(${suaveSignerB.address}) with bid amount ${bidAmounts[1].toString()}`)
        const resB = await AuctionContractB
            .submitBid
            .sendConfidentialRequest(pool, poolId, blockNumber, bidAmounts[1].toHexString());
        if (resB.status === 0) {
            console.error('🚨 Submitting bid B failed')
            process.exit(1)
        } else {
            console.log('✅ Submitting bid B suceeded')
        }

        // await sleep(3000)

        console.log("\n👀 Settling the auction")
        // todo: reenable settlement checking - slot param
        let resAuction = await AuctionContractB.settleAuction.sendConfidentialRequest(pool, poolId, blockNumber, 0);
        const receiptSettlement = await resAuction.wait()
        if (receiptSettlement.status === 0) {
            console.error('🚨 Auction settlement failed')
            process.exit(1)
        } else {
            console.log('✅ Auction settlement successful')
        }

        // Parse the result
        const decoded = AuctionContractA.interface.parseTransaction({
            data: resAuction.confidentialComputeResult
        });
        console.log(`\n✨ Auction winner: ${decoded.args[0][3]} with bid amount ${decoded.args[0][4]}`)
        console.log(`Signature: ${decoded.args[1]}`)

        process.exit(1)
        
        const encodedParams = ethers.utils.defaultAbiCoder.encode(
            ['uint64', 'uint256', 'bytes'],
            [decoded.args[0][2], decoded.args[0][4], decoded.args[1]],
        )
        console.log([decoded.args[0][2], decoded.args[0][4], decoded.args[1]])
            
        
        // SWAP 

        const arbRpc = 'https://sepolia-rollup.arbitrum.io/rpc'
        const uniRouter = '0x5bA874E13D2Cf3161F89D1B1d1732D14226dBF16'
        const uniRouterABI = require('../../abis/UniRouterABI.json')

        const provider = new ethers.providers.JsonRpcProvider(arbRpc)
        const walletA = new ethers.Wallet(rigilPKA, provider)
        const walletB = new ethers.Wallet(rigilPKB, provider)

        const RouterContract = new ethers.Contract(uniRouter, uniRouterABI, walletB)

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
        console.log(await res.wait())
	})


async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}