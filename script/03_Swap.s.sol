// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract SwapScript is Script {
    address constant POOL_MANAGER = address(0xE5dF461803a59292c6c03978c17857479c40bc46);
    address constant TOKEN1_ADDRESS = address(0xA47757c742f4177dE4eEA192380127F8B62455F5);
    address constant TOKEN2_ADDRESS = address(0xFDA93151f6146f763D3A80Ddb4C5C7B268469465);
    address constant HOOK_ADDRESS = address(0x030C65FFc979C367e58DE454bBB5841bF7aF8573);

    PoolSwapTest swapRouter = PoolSwapTest(0x5bA874E13D2Cf3161F89D1B1d1732D14226dBF16);

    // slippage tolerance to allow for unlimited price impact
    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    function run() external {
        address token0 = uint160(TOKEN2_ADDRESS) < uint160(TOKEN1_ADDRESS) ? TOKEN2_ADDRESS : TOKEN1_ADDRESS;
        address token1 = uint160(TOKEN2_ADDRESS) < uint160(TOKEN1_ADDRESS) ? TOKEN1_ADDRESS : TOKEN2_ADDRESS;
        uint24 swapFee = 4000;
        int24 tickSpacing = 10;

        // Using a hooked pool
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(HOOK_ADDRESS)
        });

        // approve tokens to the swap router
        vm.broadcast();
        IERC20(token0).approve(address(swapRouter), type(uint256).max);
        vm.broadcast();
        IERC20(token1).approve(address(swapRouter), type(uint256).max);

        // ---------------------------- //
        // Swap 100e18 token0 into token1 //
        // ---------------------------- //
        bool zeroForOne = true;
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: 1e6,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

        // in v4, users have the option to receive native ERC20s or wrapped ERC1155 tokens
        // here, we'll take the ERC20s
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({withdrawTokens: true, settleUsingTransfer: true, currencyAlreadySent: false});

        bytes memory hookData = hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000179000000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041e464c15169a97c46c2c5c86811f7974ddfe8c8ffc592fd983936ba20c7cd2dd56ea07126bdc69c4c83c9cb08fe687856cf2fbaa0fa457b3bfddae57d6449b1670000000000000000000000000000000000000000000000000000000000000000"; // TODO: Use allowed sig

        vm.broadcast();
        // swapRouter.swap(pool, params, testSettings,  new bytes(0x0));
        swapRouter.swap(pool, params, testSettings, hookData);
    }
}
