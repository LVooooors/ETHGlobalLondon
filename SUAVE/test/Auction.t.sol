// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../lib/forge-std/src/Test.sol";
import { Test, SuaveEnabled } from "../lib/suave-std/src/Test.sol";
import { Auction } from "../contracts/Auction.sol";

interface Cheatcodes {
    function startPrank(address, address) external;
    function stopPrank() external;
}

contract AuctionTest is Test, SuaveEnabled {

    address constant CSTORE = 0x0000000000000000000000000000000042020000;
    Cheatcodes constant cheatcodes = Cheatcodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function testAuction() public {
        address registry = 0x352CC6E83B37715414F65437fbddA45CC6a22054;
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

        uint256[] memory bidAmounts = new uint256[](3);
        bidAmounts[0] = 12;
        bidAmounts[1] = 200;
        bidAmounts[2] = 50;
        address[] memory addresses = new address[](3);
        addresses[0] = address(1);
        addresses[1] = address(2);
        addresses[2] = address(3);

        for (uint i = 0; i < bidAmounts.length; i++) {
            cheatcodes.startPrank(addresses[i], tx.origin);
            bytes memory res = auction.submitBid(pool, poolId, blockNumber, bidAmounts[i]);
            address(auction).call(res);
            cheatcodes.stopPrank();
        }

        Auction.Bid[] memory bids = auction.fetchBids(pool, poolId, blockNumber);
        for (uint i = 0; i < bids.length; i++) {
            assert(bids[i].pool == pool);
            assert(bids[i].poolId == poolId);
            assert(bids[i].blockNumber == blockNumber);
            assert(bids[i].bidAmount == bidAmounts[i]);
        }

        // settleAuction
        address winner = address(2);
        bytes memory res4 = auction.settleAuction(pool, poolId, blockNumber, 0);
        address(auction).call(res4);

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
