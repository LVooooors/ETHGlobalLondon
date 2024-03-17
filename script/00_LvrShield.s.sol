// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "v4-core/src/test/PoolDonateTest.sol";
import {LvrShield} from "../src/LvrShield.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";

contract LvrShieldScript is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant ARBITRUM_SEPOLIA_POOLMANAGER = address(0xE5dF461803a59292c6c03978c17857479c40bc46);

    function setUp() public {}

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(LvrShield).creationCode, abi.encode(address(ARBITRUM_SEPOLIA_POOLMANAGER)));

        // Deploy the hook using CREATE2
        vm.broadcast();
        LvrShield lvrShield = new LvrShield{salt: salt}(IPoolManager(address(ARBITRUM_SEPOLIA_POOLMANAGER)));
        require(address(lvrShield) == hookAddress, "LvrShieldScript: hook address mismatch");
    }
}
