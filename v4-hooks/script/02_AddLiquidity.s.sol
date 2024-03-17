// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

contract AddLiquidityScript is Script {
    using CurrencyLibrary for Currency;

    address constant POOL_MANAGER = address(0xE5dF461803a59292c6c03978c17857479c40bc46);
    address constant TOKEN1_ADDRESS = address(0xA47757c742f4177dE4eEA192380127F8B62455F5);
    address constant TOKEN2_ADDRESS = address(0xFDA93151f6146f763D3A80Ddb4C5C7B268469465);
    address constant HOOK_ADDRESS = address(0x0301cF874CDB90ea311354eC6518aeF36F00C5FE);

    PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(address(0xd962b16F4ec712D705106674E944B04614F077be));

    function run() external {
        // sort the tokens!
        address token0 = uint160(TOKEN2_ADDRESS) < uint160(TOKEN1_ADDRESS) ? TOKEN2_ADDRESS : TOKEN1_ADDRESS;
        address token1 = uint160(TOKEN2_ADDRESS) < uint160(TOKEN1_ADDRESS) ? TOKEN1_ADDRESS : TOKEN2_ADDRESS;
        uint24 swapFee = 4000; // 0.40% fee tier
        int24 tickSpacing = 10;

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(HOOK_ADDRESS)
        });

        // approve tokens to the LP Router
        vm.broadcast();
        IERC20(token0).approve(address(lpRouter), 2e18);
        vm.broadcast();
        IERC20(token1).approve(address(lpRouter), 2e18);

        // optionally specify hookData if the hook depends on arbitrary data for liquidity modification
        bytes memory hookData = new bytes(0);

        // logging the pool ID
        PoolId id = PoolIdLibrary.toId(pool);
        bytes32 idBytes = PoolId.unwrap(id);
        console.log("Pool ID Below");
        console.logBytes32(bytes32(idBytes));

        // Provide liquidity on the range of [-600, 600]
        vm.broadcast();
        lpRouter.modifyLiquidity(pool, IPoolManager.ModifyLiquidityParams(-600, 600, 1e18), hookData);
    }
}
