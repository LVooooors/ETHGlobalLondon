// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

//import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// See https://github.com/Uniswap/v4-core/blob/main/src/types/PoolId.sol
type PoolId is bytes32;

// Definition from https://github.com/Uniswap/v4-core/blob/main/src/types/BalanceDelta.sol
type BalanceDelta is int256;

// Definition from https://github.com/Uniswap/v4-core/blob/main/src/types/Currency.sol
type Currency is address;

// TODO: SafeERC20
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// Definition from https://github.com/Uniswap/v4-core/blob/main/src/types/PoolKey.sol
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    address hooks;
}

// From https://github.com/Uniswap/v4-core/blob/main/src/PoolManager.sol
interface IUniswapV4 {
    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        //override
        //noDelegateCall
        //isLocked
        returns (BalanceDelta delta);
}

contract EscrowRegistry {

    address auctionMaster;
    address hookAddress;

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
        PoolId pool;
        uint256 blockNumber;
        uint256 bidAmount;
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

    constructor(address masterKey, address hooks) {
        auctionMaster = masterKey;
        hookAddress = hooks;
    }

    function updateAuctionMasterKey(address updatedKey) public {
        // Relax, it's a hackathon
        auctionMaster = updatedKey;
    }

    function updateHooks(address updatedHook) public {
        // Relax, it's a hackathon
        hookAddress = updatedHook;
    }

    function registerNewPool(address v4Contract, PoolId id, address poolTokenA, address poolTokenB) public {
        poolTokens[v4Contract][id] = Tokens(poolTokenA, poolTokenB);
    }

    function depositAndClaimOrdering(address v4Contract, PoolId id, address user, address token, uint256 amount, uint256 blockNumber, bytes memory sig) public {
        require(depositFunds(v4Contract, id, user, token, amount), "Failed to deposit");
        require(claimPriorityOrdering(v4Contract, id, user, token, amount, blockNumber, sig), "Failed to claim ordering");
    }

    function claimPriorityOrdering(address v4Contract, PoolId id, address user, address token, uint256 amount, uint256 blockNumber, bytes memory sig) public returns (bool) {
        bytes32 bidDigest = createBidDigest(user, id, blockNumber, amount); 
        require(recoverSigner(bidDigest, sig) == auctionMaster, "Auction master address mismatch");

        require(hasSufficientFundsToPayforOrdering(v4Contract, id, user, token, amount), "Insufficient funds");

        // charge token
        escrow[v4Contract][id][token][user].amountSpent += amount;

        // If ok, then set ordering priority
        priorityOrdering[v4Contract][id][user][blockNumber] = true;
        return true;
    }

    function hasSufficientFundsToPayforOrdering(address v4Contract, PoolId id, address user, address token, uint256 amount) public view returns (bool) {
        uint256 remainingAmount = escrow[v4Contract][id][token][user].amount - escrow[v4Contract][id][token][user].amountSpent;
        return remainingAmount >= amount;
    }

    function isOwnerOfPriorityOrdering(address v4Contract, PoolId id, address user, uint256 blockNumber) public view returns (bool) {
        return priorityOrdering[v4Contract][id][user][blockNumber];
    }

    function depositFunds(address v4Contract, PoolId id, address user, address token, uint256 amount) public returns (bool) {
        // Shortcut for hackathon - only support payments in pool token0
        require(checkValidtoken(v4Contract, id, token), "Invalid token supplied, only token0 supported");
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

    function enrichLPers(address v4Contract, PoolId id, address token, address user) public {
        require(escrow[v4Contract][id][token][user].amount >= escrow[v4Contract][id][token][user].amountSpent, "Amounts mismatch");

        address t0 = poolTokens[v4Contract][id].tokenA;
        address t1 = poolTokens[v4Contract][id].tokenB;
        PoolKey memory key = createPoolKey(t0, t1);
        
        uint256 amountToEnrich = escrow[v4Contract][id][token][user].amountSpent;
        IUniswapV4(v4Contract).donate(key, amountToEnrich, 0, new bytes(0));

        escrow[v4Contract][id][token][user].amount -= escrow[v4Contract][id][token][user].amountSpent;
        escrow[v4Contract][id][token][user].amountSpent = 0;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        if (v < 27) {
            v += 27;
        }
    }

    function createBidDigest(address user, PoolId id, uint256 blockNumber, uint256 amountOfBid) public pure returns (bytes32) {
        Bid memory bidStruct = Bid(user, id, blockNumber, amountOfBid);
        return keccak256(abi.encode(bidStruct));
    }

    function checkValidtoken(address v4Contract, PoolId id, address token) public view returns (bool) {
        return poolTokens[v4Contract][id].tokenA == token;
    }

    // Borrowed from https://github.com/Uniswap/v4-periphery/blob/main/test/Quoter.t.sol#L535
    function createPoolKey(address tokenA, address tokenB)
        internal
        view 
        returns (PoolKey memory)
    {
        if (address(tokenA) > address(tokenB)) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey(Currency.wrap(address(tokenA)), Currency.wrap(address(tokenB)), 3000, 60, hookAddress);
    }

}
