const { config: dconfig } = require('dotenv')
require('@nomiclabs/hardhat-ethers')

dconfig()

require('./script/deploy')

function getEnvValSafe(key) {
	const endpoint = process.env[key]
	if (!endpoint)
		throw(`Missing env var ${key}`)
	return endpoint
}

const RIGIL_PK = getEnvValSafe('RIGIL_PK')
const RIGIL_RPC = getEnvValSafe('RIGIL_RPC')

module.exports = {
	solidity: '0.8.13',
	defaultNetwork: 'rigil',
	namedAccounts: {
		deployer: {
			default: 0,
		}
	},
	networks: {
		rigil: {
			chainId: 16813125,
			url: RIGIL_RPC,
			accounts: [ RIGIL_PK ],
			companionNetworks: {
				goerli: 'goerli',
			},
		}
	}
}
