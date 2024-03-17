// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../lib/forge-std/src/Test.sol";
import { Test, SuaveEnabled } from "../lib/suave-std/src/Test.sol";
import { Auction } from "../contracts/Auction.sol";

contract AuctionTest is Test, SuaveEnabled {

    address constant CSTORE = 0x0000000000000000000000000000000042020000;

    function testAuction() public {
        address registry = 0xFfe8e2f2aA5BB81E13EDc3b5c51be045d97f1A1A;
        string memory settlementChainRpc = "https://sepolia-rollup.arbitrum.io/rpc";
        Auction auction = new Auction(registry, settlementChainRpc); 

        bytes memory res = auction.confidentialConstructor();
        address(auction).call(res);
        console.log(auction.internalWallet());
        assert(auction.internalWallet() != address(0));
        assert(auction.isInitialized());

        // submitBid
        address pool = address(1);
        bytes32 poolId = bytes32("");
        uint64 blockNumber = 3;

        uint256[] memory bidAmounts = new uint256[](2);
        bidAmounts[0] = 12;
        bidAmounts[1] = 200;
        bytes memory res2 = auction.submitBid(pool, poolId, blockNumber, bidAmounts[0]);
        address(auction).call(res2);
        bytes memory res3 = auction.submitBid(pool, poolId, blockNumber, bidAmounts[1]);
        address(auction).call(res2);

        Auction.Bid[] memory bids = auction.fetchBids(pool, poolId, blockNumber);
        for (uint i = 0; i < bids.length; i++) {
            assert(bids[i].pool == pool);
            assert(bids[i].poolId == poolId);
            assert(bids[i].blockNumber == blockNumber);
            assert(bids[i].bidAmount == bidAmounts[i]);
        }

        // settleAuction
        // address winner = address(2);
        // bytes memory res4 = auction.settleAuction(pool, poolId, blockNumber);
        // address(auction).call(res4);
        // (bytes4 methodsig, Auction.Bid memory bid,) = abi.decode(res4, (bytes4, Auction.Bid, bytes));
        

    }

    function testSig() public {
        address registry = 0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03;
        string memory settlementChainRpc = "https://goerli.gateway.tenderly.co";
        Auction auction = new Auction(registry, settlementChainRpc); 

        bytes memory res = auction.confidentialConstructor();
        address(auction).call(res);    
        console.log(auction.internalWallet());
        assert(auction.internalWallet() != address(0));
        assert(auction.isInitialized());

        bytes memory res2 = auction.signBid(Auction.Bid(
            0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03,
            0x6c00000000000000000000000000000000000000000000000000000000000000,
            600,
            0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03,
            5
        ));
        console.logBytes(res2);
    }

    function testBeaconSlotToBlockNum() public {
        address registry = 0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03;
        string memory settlementChainRpc = "https://goerli.gateway.tenderly.co";
        Auction auction = new Auction(registry, settlementChainRpc); 
        auction.slotToBlockNumber(8651711);
    }
}
