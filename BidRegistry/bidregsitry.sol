pragma solidity ^0.8.24;

//import {PoolKey} from "v4-core/src/types/PoolKey.sol";
type PoolId is bytes32;

// TODO: SafeERC20
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract EscrowRegistry {

    address auctionMaster;

    struct LockedBalance {
        // Total amount held in contract
        uint256 amount;
        // Total amount spent
        uint256 amountSpent;
        //uint256 unlockBlock;
    }

    struct Tokens {
        // TODO IERC20
        address tokenA;
        address tokenB;
    }

    // Signed data structure from SUAVE auction
    struct Bid {
        address bidder;
        address pool;
        uint blockNumber;
        uint bidAmount;
    }

    // Mapping between user and specific pool locked funds
    //  v4 contract address
    //      pool id within v4
    //          address of user
    //              address of token
    mapping(address => 
        mapping(PoolId => 
            mapping(address => 
                mapping(address => addressLockedBalance))) public escrow;

    mapping(address => 
        mapping(PoolId => Tokens)) public poolTokens;

    constructor(address auctionMaster) { }

    function registerNewPool(address v4Contract, PoolId id, address poolTokenA, address poolTokenB) public {
        // call pool get tokens
        poolTokens[v4Contract][id] = Tokens(poolTokenA, poolTokenB);
    }

    function depositAndlock() ..

    function lock(address token, uint256 amount, uint256 unlockBlock) public {
        //require(balances[token][account].amount == 0, "Amount already locked");
        escrow[token][account] = LockedBalance(amount, unlockBlock);
    }

    function depositFunds(address v4Contract, PoolId id, address user, address token, uint256 amount) public {
        IERC20 tokenContract = IERC20(token);
        require(tokenContract.transferFrom(user, address(this), amount), "Transfer failed");
        escrow[token][account].amount += amount;
    }

    function withdrawIdleFunds(address v4Contract, PoolId id, address user) public {
        require(escrow[token][account].amount > escrow[token][account].amountSpent, "No idle funds")
        uint256 amount = escrow[token][account].amount - escrow[token][account].amountSpent;
        require(tokenContract.transfer(user, amount), "Transfer failed");
        escrow[token][account].amount -= amount;
    }

    function enrichLPers() public {}

}