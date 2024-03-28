// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";

import {BidRegistry} from "./BidRegistry.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

// From SUAVE, for reference:
struct BidData {
    address pool;
    // bytes32 poolId;
    address bidder;
    uint64 blockNumber;
    uint bidAmount;
    bytes sig;
}

contract LvrShield is BaseHook {
    using PoolIdLibrary for PoolKey;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId poolId => mapping(uint blockNumber => uint256 poolBlockSwapCounter)) public blockSwapCounter;
    
    address bidRegistry;
    
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
    }

    function setBidRegistry(address _bidRegistry) public {
        bidRegistry = _bidRegistry;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata swapParams, bytes calldata hookData)
        external
        override
        returns (bytes4)
    {
        // Check if top of block for this pair
        if (blockSwapCounter[key.toId()][block.number]==0) {
            // If yes, check if it won the auction - or revert

            address v4ContractHookAddress = address(this);
            address feeToken = 0xA47757c742f4177dE4eEA192380127F8B62455F5; // TODO: Make dynamic

            PoolId poolId = key.toId();
            BidData memory bidData = abi.decode(hookData, (BidData));
            // require(bidData.bidder == tx.origin, "tx.origin is not the auction winner");
            // require(bidData.pool == v4ContractHookAddress, "incorrect pool address"); // TODO: Re-add

            require(BidRegistry(bidRegistry).claimPriorityOrdering(
                v4ContractHookAddress,
                poolId, 
                bidData.bidder,
                feeToken, 
                bidData.bidAmount, 
                bidData.blockNumber, 
                bidData.sig
            ), "This is a top of block swap but it wasn't the auction winner");
            // TODO once timing alignment sorted out: Ensure block.number == bidData.blockNumber
        }
        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4)
    {
        blockSwapCounter[key.toId()][block.number]++;
        return BaseHook.afterSwap.selector;
    }

}
