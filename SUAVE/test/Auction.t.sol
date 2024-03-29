// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../lib/forge-std/src/Test.sol";
import { Test, SuaveEnabled } from "../lib/suave-std/src/Test.sol";
import { Auction } from "../contracts/Auction.sol";


interface Cheatcodes {
    function startPrank(address, address) external;
    function stopPrank() external;
    function warp(uint256) external;
}

contract AuctionTest is Test, SuaveEnabled {

    address constant CSTORE = 0x0000000000000000000000000000000042020000;
    Cheatcodes constant cheatcodes = Cheatcodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function testAuction() public {
        address registry = 0xa43e520783230a2347946EAC7946A92a8379781c;
        string memory settlementChainRpc = "https://sepolia-rollup.arbitrum.io/rpc";
        Auction auction = new Auction(registry, settlementChainRpc); 

        bytes memory res = auction.confidentialConstructor();
        address(auction).call(res);
        console.log(auction.internalWallet());
        assert(auction.internalWallet() != address(0));
        assert(auction.isInitialized());

        // submit bids
        address pool = 0x030C65FFc979C367e58DE454bBB5841bF7aF8573;
        bytes32 poolId = hex"3d28010ea8d317e6253d9657546ec5a268aabe64f811da773363a0cfdce4cdfd";
        uint64 blockNumber = 3;

        uint256[] memory bidAmounts = new uint256[](2);
        bidAmounts[0] = 12;
        bidAmounts[1] = 200;
        address[] memory addresses = new address[](2);
        addresses[0] = 0x2f11299cb7d762F01b55EEa66f79e4cB02F02786;
        addresses[1] = 0x093354a6405D79f8a2C9C0480a944c17aF72BE8A;

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

        address winningBidder = address(0);
        assembly {
            winningBidder := mload(add(res4, 132))
        }
        assert(winningBidder == addresses[1]);
    }

    function testSig() public {
        address registry = 0xa43e520783230a2347946EAC7946A92a8379781c;
        string memory settlementChainRpc = "https://sepolia-rollup.arbitrum.io/rpc";
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
        bytes memory sigExpected = hex"46065f0a22c299f4d7ef2c130768acbf004621b83402eaec301e8d6dc65989de28111f80ead942fa4f7706e49668e0ce9891595459116715c37d5fdb5e3c3b1500";
        
        assert(keccak256(res2) == keccak256(sigExpected));
    }

    function testBeaconSlotToBlockNum() public {
        address registry = 0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03;
        string memory settlementChainRpc = "https://goerli.gateway.tenderly.co";
        string memory beaconBaseUrl = "https://docs-demo.quiknode.pro/eth/v2/beacon/blocks/";

        Auction auction = new Auction(registry, settlementChainRpc); 
        auction.setBeaconBaseUrl(beaconBaseUrl);

        uint blockNum = auction.slotToBlockNumber(8651711);

        assert(blockNum == 19451771);
    }

    function testCheckForValidSettlement() public {
        address registry = 0x7b6aceC5eA36DD5ef5b0639B8C1d0Dab59DdcF03;
        string memory settlementChainRpc = "https://goerli.gateway.tenderly.co";
        string memory beaconBaseUrl = "https://docs-demo.quiknode.pro/eth/v2/beacon/blocks/";
        uint slot = 8621553;
        uint blockNum = 19421996;
        uint slotTimestamp = 1710282659;

        cheatcodes.warp(slotTimestamp-1);
        Auction auction = new Auction(registry, settlementChainRpc);
        auction.setBeaconBaseUrl(beaconBaseUrl);

        auction.checkForValidSettlement(slot, blockNum);
    }

}
