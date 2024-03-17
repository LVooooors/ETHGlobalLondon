// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/ERC20.sol";

contract LvrShieldToken1 is ERC20 {
    // Deployed: https://sepolia.arbiscan.io/token/0xa47757c742f4177de4eea192380127f8b62455f5
    constructor() ERC20("LvrShieldToken1", "LVRST1") {
        // Mint 100 tokens to msg.sender
        // Similar to how
        // 1 dollar = 100 cents
        // 1 token = 1 * (10 ** decimals)
        _mint(msg.sender, 100 * 10 ** uint(decimals()));
    }
}

contract LvrShieldToken2 is ERC20 {
    // Deployed: https://sepolia.arbiscan.io/token/0xfda93151f6146f763d3a80ddb4c5c7b268469465
    constructor() ERC20("LvrShieldToken2", "LVRST2") {
        // Mint 100 tokens to msg.sender
        // Similar to how
        // 1 dollar = 100 cents
        // 1 token = 1 * (10 ** decimals)
        _mint(msg.sender, 100 * 10 ** uint(decimals()));
    }
}
