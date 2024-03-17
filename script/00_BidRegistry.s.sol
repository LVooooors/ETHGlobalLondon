// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {BidRegistry} from "../src/BidRegistry.sol";

contract BidRegistryScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        new BidRegistry(0x54a4dDa9CE124774aEaEDb9056fD14f98b55AFFC, address(this));
    }
}
