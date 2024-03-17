# LVooooors @ ETHGlobalLondon 2024

## tl;dr:

We fix LVR in Uniswap via v4 hooks using external SUAVE calls for credible second-bid (Vickery) auctions for top-of-block arb-swap rights, redistributing the profit to the LPs.

![alt text](image.png)

https://app.excalidraw.com/l/ZvFp528akJ/3OK2MBMiduH


## Project Setup

Requires [foundry](https://book.getfoundry.sh):

```
forge install
```


## Development and Testing

### Local Unit Tests

See [./test](./test), run with `forge test`.


### Anvil

```bash
# start anvil with TSTORE support
# (`foundryup`` to update if cancun is not an option)
anvil --hardfork cancun

# in a new terminal
forge script script/Anvil.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```


### Testnet Deployment

Note: Both Ethereum Goerli and Ethereum Sepolia are NOT supported by Uniswap v4 currently.

However, we were able to deploy our hook, create a pool, add liquidity and swap successfully using Arbitrum Sepolia. 

Further testnets presumed to be functional (as of 17 March 2024):

```
https://sepolia-rollup.arbitrum.io/rpc
- PoolManager deployed to 0xE5dF461803a59292c6c03978c17857479c40bc46
- PoolModifyLiquidityTest deployed to 0xd962b16F4ec712D705106674E944B04614F077be
- PoolSwapTest deployed to 0x5bA874E13D2Cf3161F89D1B1d1732D14226dBF16

https://sepolia.base.org
- PoolManager deployed to 0xd962b16F4ec712D705106674E944B04614F077be
- PoolModifyLiquidityTest deployed to 0x5bA874E13D2Cf3161F89D1B1d1732D14226dBF16
- PoolSwapTest deployed to 0x60AbEb98b3b95A0c5786261c1Ab830e3D2383F9e

https://sepolia.optimism.io
- PoolManager deployed to 0xb673AE03413860776497B8C9b3E3F8d4D8745cB3
- PoolModifyLiquidityTest deployed to 0x862Fa52D0c8Bca8fBCB5213C9FEbC49c87A52912
- PoolSwapTest deployed to 0x30654C69B212AD057E817EcA26da6c5edA32E2E7

https://rpc.ankr.com/polygon_mumbai
- PoolManager deployed to 0xf3A39C86dbd13C45365E57FB90fe413371F65AF8
- PoolModifyLiquidityTest deployed to 0xFDABa2b9C369C25f5834334612c0855497942788
- PoolSwapTest deployed to 0x76870DEbef0BE25589A5CddCe9B1D99276C73B4e

https://rpc.public.zkevm-test.net
- PoolManager deployed to 0x615bCf3371F7daF8E8f7d26db10e12F0F4830C94
- PoolModifyLiquidityTest deployed to 0x3A0c2cF7c40A7B417AE9aB6ccBF60e86d8437395
- PoolSwapTest deployed to 0x3D5e538D212b05bc4b3F70520189AA3dEA588B1E
```

To deploy to a testnet, run scripts from [./script](./script), e.g.:
```
forge script script/00_BidRegistry.s.sol \
--rpc-url https://sepolia-rollup.arbitrum.io/rpc \
--private-key [your_private_key_on_separbitrum_here] \
--broadcast
```

#### *Deploying your own Tokens For Testing*

Because v4 is still in testing mode, most networks don't have liquidity pools live on v4 testnets. We recommend launching your own test tokens and expirementing with them that:

```
forge create script/mocks/mUNI.sol:MockUNI \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key_here]
```

```
forge create script/mocks/mUSDC.sol:MockUSDC \
--rpc-url [your_rpc_url_here] \
--private-key [your_private_key_here]
```

## Troubleshooting

### Permission Denied

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh) 

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

### Hook Deployment Failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
    * `getHookCalls()` returns the correct flags
    * `flags` provided to `HookMiner.find(...)`
2. Verify salt mining is correct:
    * In **forge test**: the *deploye*r for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
    * In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
        * If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`


### Additional Resources

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

[v4-by-example](https://v4-by-example.org)


## Hackathon Deployment

- SUAVE contract: https://explorer.rigil.suave.flashbots.net/address/0xBb31e85bd7ABb995A020BDb91352c331368C8e19
- BidRegistry: https://sepolia.arbiscan.io/address/0xccf033a3ac520432c0ade7a3765a00087e2ec3e5
- LvrShield hook: https://sepolia.arbiscan.io/address/0x030418916cb8A600dc02d307204dD8828b3aA179


## Hackathon Observations

- Arbitrum-Sepolia RPC sometimes throws this error: `It looks like you're trying to fork from an older block with a non-archive node which is not supported. Please try to change your RPC url to an archive node if the issue persists.`. Workaround: Just re-run the deployment script.
- https://github.com/Uniswap/docs/pull/676 


## Limitations & Future Work

- Block number needs to be re-enabled; cross-network time-syncing is non-trivial.


## Prizes/Bounties

### Flashbots

SUAVE.

### Nethermind

SUAVE & MEV.

### Uniswap

SUAVE v4 hooks.
