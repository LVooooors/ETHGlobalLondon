const { config: dconfig } = require('dotenv')
require('@nomiclabs/hardhat-ethers')

dconfig()

require('./script/deploy')
require('./script/action')

function getEnvValSafe(key) {
	const endpoint = process.env[key]
	if (!endpoint)
		throw(`Missing env var ${key}`)
	return endpoint
}

const RIGIL_PK = getEnvValSafe('RIGIL_PK')
const RIGIL_RPC = getEnvValSafe('RIGIL_RPC')
const RIGIL_PK_1 = getEnvValSafe('RIGIL_PK_1')
const RIGIL_PK_2 = getEnvValSafe('RIGIL_PK_2')

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
			accounts: [ RIGIL_PK, RIGIL_PK_1, RIGIL_PK_2 ],
			companionNetworks: {
				goerli: 'goerli',
			},
		}
	}
}
