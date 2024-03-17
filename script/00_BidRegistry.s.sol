// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {BidRegistry} from "../src/BidRegistry.sol";

contract BidRegistryScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        new BidRegistry(address(this), address(this));
    }
}
