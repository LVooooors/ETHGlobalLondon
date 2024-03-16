// SPDX-License-Identifier: MIT
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
    }

    struct Tokens {
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
                mapping(address => LockedBalance)))) public escrow;

    // Mapping between user and specific pool locked funds
    //  v4 contract address
    //      pool id within v4
    //          address of user
    //              block number
    mapping(address => 
        mapping(PoolId => 
            mapping(address =>
                mapping(uint256 => bool )))) public priorityOrdering;
    

    mapping(address => 
        mapping(PoolId => Tokens)) public poolTokens;

    constructor(address masterKey) {
        auctionMaster = masterKey;
    }

    function updateAuctionMasterKey(address updatedKey) public {
        // Relax, it's a hackathon
        auctionMaster = updatedKey;
    }

    function registerNewPool(address v4Contract, PoolId id, address poolTokenA, address poolTokenB) public {
        // TODO call pool get tokens
        poolTokens[v4Contract][id] = Tokens(poolTokenA, poolTokenB);
    }

    function depositAndClaimOrdering(address v4Contract, PoolId id, address user, address token, uint256 amount, uint256 blockNumber) public {
        require(depositFunds(v4Contract, id, user, token, amount), "Failed to deposit");
        require(claimPriorityOrdering(v4Contract, id, user, token, amount, blockNumber), "Failed to claim ordering");
    }

    function claimPriorityOrdering(address v4Contract, PoolId id, address user, address token, uint256 amount, uint256 blockNumber) public returns (bool) {
        // TODO charge token
        
        // If ok, then set ordering priority
        priorityOrdering[v4Contract][id][user][blockNumber] = true;
        return true;
    }

    function isOwnerOfPriorityOrdering(address v4Contract, PoolId id, address user, uint256 blockNumber) public view returns (bool) {
        return priorityOrdering[v4Contract][id][user][blockNumber];
    }

    function depositFunds(address v4Contract, PoolId id, address user, address token, uint256 amount) public returns (bool) {
        IERC20 tokenContract = IERC20(token);
        require(tokenContract.transferFrom(user, address(this), amount), "Transfer failed");
        escrow[v4Contract][id][token][user].amount += amount;
        return true;
    }

    function withdrawIdleFunds(address v4Contract, PoolId id, address token, address user) public returns (bool) {
        require(escrow[v4Contract][id][token][user].amount > escrow[v4Contract][id][token][user].amountSpent, "No idle funds");
        uint256 amount = escrow[v4Contract][id][token][user].amount - escrow[v4Contract][id][token][user].amountSpent;
        require(IERC20(token).transfer(user, amount), "Transfer failed");
        escrow[v4Contract][id][token][user].amount -= amount;
        return true;
    }

    function enrichLPers() public {
        // TODO work out how to donate to a pool
    }

}