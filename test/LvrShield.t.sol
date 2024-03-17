// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {LvrShield} from "../src/LvrShield.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {BidRegistry} from "../src/BidRegistry.sol";
import {IERC20} from "../lib/v4-core/lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";


// From SUAVE, for reference:
struct BidData {
    // address pool;
    // bytes32 poolId;
    address bidder;
    uint64 blockNumber;
    uint bidAmount;
    bytes sig;
}

contract LvrShieldTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    LvrShield lvrShield;
    PoolId poolId;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        (currency0, currency1) = Deployers.deployMintAndApprove2Currencies();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        (address hookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(LvrShield).creationCode, abi.encode(address(manager)));

        lvrShield = new LvrShield{salt: salt}(IPoolManager(address(manager)));

        BidRegistry bidRegistry = new BidRegistry(address(0x00000000000000000000000080b3247491dd7843e0bb85cb8a403fcbedcc2813), address(lvrShield));

        lvrShield.setBidRegistry(address(bidRegistry));
        
        require(address(lvrShield) == hookAddress, "LvrShieldTest: hook address mismatch");

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(lvrShield)));
        poolId = key.toId();
        manager.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);

        // Provide liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether),
            ZERO_BYTES
        );

        console.log(currency0.balanceOf(address(this)));

        bidRegistry.registerNewPool(address(0x0),poolId,Currency.unwrap(currency0),Currency.unwrap(currency1));
        IERC20(Currency.unwrap(currency0)).approve(address(bidRegistry), UINT256_MAX);
        bidRegistry.depositFunds(address(0x0), poolId, address(this), address(0x0), 500000);
        // console.log(IERC20(Currency.unwrap(currency0)).balanceOf(address(this)));
        // IERC20(Currency.unwrap(currency0)).balanceOf(address(bidRegistry));
        console.log("Setup successful");
    }

    function testLvrShieldHooks() public {
        // positions were created in setup()
        // console.log(lvrShield.blockSwapCounter(poolId, block.number));
        assertEq(lvrShield.blockSwapCounter(poolId, block.number), 0);

        // Perform a test swap 1 //

        bool zeroForOne = true;
        int256 amountSpecified = -20; // negative number indicates exact input swap!
        BidData memory bidData = BidData({
            blockNumber: 2134116, 
            bidAmount: 2000000000000000, 
            sig: hex'fcd8905495f10f76e023b7f6f4d358a4ea6b8ca087897755a5545e997a8bc77d32c3c52eb5ec9d53efc229676ef8482c5a662c77cd354a6922a9e0a834f8f50000',
            // bidder: 0x2f11299cb7d762F01b55EEa66f79e4cB02F02786
            bidder: address(this)
        });

        console.log(msg.sender);
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, abi.encode(bidData));

        assertEq(int256(swapDelta.amount0()), amountSpecified);
        assertEq(lvrShield.blockSwapCounter(poolId, block.number), 1);

        // Perform a test swap 2 //

        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        assertEq(lvrShield.blockSwapCounter(poolId, block.number), 2);

        console.log("Two swaps successful");
    }
    
    // function testLiquidityHooks() public {
    //     // positions were created in setup()

    //     // remove liquidity
    //     int256 liquidityDelta = -1e18;
    //     modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, liquidityDelta), ZERO_BYTES);

    // }
}
