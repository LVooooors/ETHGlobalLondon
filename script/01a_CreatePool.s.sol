// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

contract CreatePoolScript is Script {
    using CurrencyLibrary for Currency;

    //addresses with contracts deployed
    address constant POOL_MANAGER = address(0xE5dF461803a59292c6c03978c17857479c40bc46);
    address constant TOKEN1_ADDRESS = address(0xA47757c742f4177dE4eEA192380127F8B62455F5);
    address constant TOKEN2_ADDRESS = address(0xFDA93151f6146f763D3A80Ddb4C5C7B268469465);
    address constant HOOK_ADDRESS = address(0x0301cF874CDB90ea311354eC6518aeF36F00C5FE);

    function run() external {
        // sort the tokens!
        address token0 = uint160(TOKEN2_ADDRESS) < uint160(TOKEN1_ADDRESS) ? TOKEN2_ADDRESS : TOKEN1_ADDRESS;
        address token1 = uint160(TOKEN2_ADDRESS) < uint160(TOKEN1_ADDRESS) ? TOKEN1_ADDRESS : TOKEN2_ADDRESS;
        uint24 swapFee = 4000;
        int24 tickSpacing = 10;

        // floor(sqrt(1) * 2^96)
        uint160 startingPrice = 79228162514264337593543950336;

        bytes memory hookData = abi.encode(block.timestamp);

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: swapFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(HOOK_ADDRESS)
        });

        // Turn the Pool into an ID so you can use it for modifying positions, swapping, etc.
        PoolId id = PoolIdLibrary.toId(pool);
        bytes32 idBytes = PoolId.unwrap(id);

        console.log("Pool ID Below");
        console.logBytes32(bytes32(idBytes));

        vm.broadcast();
        IPoolManager(POOL_MANAGER).initialize(pool, startingPrice, hookData);
    }
}
