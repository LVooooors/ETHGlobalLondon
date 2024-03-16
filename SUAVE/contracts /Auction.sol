pragma solidity ^0.8.9;

import "./lib/SuaveContract.sol";


contract VickyLVRHookup is SuaveContract {

    // todo: use storage to indentify an auction (set id and map details to it) (smaller events) eg. pool hash

    struct Bid {
        address pool;
        bytes32 poolId;
        uint64 blockNumber;
        address bidder;
        uint bidAmount;
    }

    event BidSubmitted(
        address indexed pool,
        bytes32 indexed poolId, 
        uint64 indexed blockNumber, 
        address bidder, // todo index 
        uint bidAmount
    );

    event AuctionSettled(
        address indexed pool,
        bytes32 indexed poolId, 
        uint64 indexed blockNumber, 
        address winner, // todo index 
        uint bidAmount, 
        bytes sig
    );

    string constant PK_NAMESPACE = "auction:v0:pksecret";
    string constant BID_NAMESPACE = "auction:v0:bids";
    bool internal isInitialized;
    Suave.DataId internal pkBidId;

    address public internalWallet;
    address public registry;
    uint64 public lastAuctionBlock;

    // ⛓️ EVM Methods

    constructor(address _registry) {
        registry = _registry;
    }

    function confidentialConstructorCallback(
        Suave.DataId _pkBidId, 
        address pkAddress
    ) public {
        crequire(!isInitialized, "Already initialized");
        pkBidId = _pkBidId;
        internalWallet = pkAddress;
        isInitialized = true;
    }

    // todo: protect it
    function submitBidCallback(Bid memory bid) public {
        emit BidSubmitted(bid.pool, bid.poolId, bid.blockNumber, bid.bidder, bid.bidAmount);
    }

    // todo: protect it
    function settleAuctionCallback(Bid memory winningBid, bytes memory sig) public {
        emit AuctionSettled(
            winningBid.pool,
            winningBid.poolId, 
            winningBid.blockNumber, 
            winningBid.bidder, 
            winningBid.bidAmount, 
            sig
        );
    }

    // 🤐 MEVM Methods

    function confidentialConstructor() external onlyConfidential returns (bytes memory) {
        crequire(!isInitialized, "Already initialized");

        string memory pk = Suave.privateKeyGen(Suave.CryptoSignature.SECP256);
        address pkAddress = getAddressForPk(pk);
		Suave.DataId bidId = storePK(bytes(pk));

        return abi.encodeWithSelector(
            this.confidentialConstructorCallback.selector, 
            bidId,
            pkAddress
        );
    }

    function submitBid(
        address pool,
        bytes32 poolId, 
        uint64 blockNumber, 
        uint bidAmount
    ) public returns (bytes memory) {
        address bidder = msg.sender;
        // todo: Call settlement chain to check if the bidder has enough funds to bid

        storeBid(Bid(pool, poolId, blockNumber, bidder, bidAmount));

        return abi.encodeWithSelector(
            this.submitBidCallback.selector, 
            Bid(pool, poolId, blockNumber, bidder, bidAmount)
        );
    }

    // todo: add v4Contract

    function checkSufficientFundsLocked(
        address pool, 
        bytes32 poolId,
        address user, 
        uint bidAmount
    ) public returns (bool) {
        bytes memory callData = abi.encodeWithSignature(
            "hasSufficientFundsToPayforOrdering",
            pool, 
            poolId,
            user, 
            address(0), 
            bidAmount
        );

        // hasSufficientFundsToPayforOrdering(address v4Contract, PoolId id, address user, address token, uint256 amount)
    }

    function settleAuction(address pool, bytes32 poolId, uint64 blockNumber) public returns (bytes memory) {
        // todo: condition to check if the auction should be over
        Bid[] memory bids = fetchBids(poolId, blockNumber);
        (Bid memory winningBid) = bids.length == 0
            ? Bid(pool, poolId, blockNumber, address(0), 0)
            : findWinningBid(bids);

        bytes memory sig = signBid(winningBid);
        
        return abi.encodeWithSelector(
            this.settleAuctionCallback.selector, 
            winningBid,
            sig
        );      
    }

    function signBid(Bid memory bid) public returns (bytes memory sig) {
        string memory pk = retreivePK();
        sig = Suave.signMessage(abi.encode(bid), Suave.CryptoSignature.SECP256, pk);
    }

    function findWinningBid(Bid[] memory bids) internal pure returns (Bid memory bestBid) {
        uint scndBestBidAmount;
        for (uint i = 0; i < bids.length; i++) {
            Bid memory bid = bids[i];
            if (bid.bidAmount > bestBid.bidAmount) {
                scndBestBidAmount = bestBid.bidAmount;
                bestBid = bid;
            } else if (bid.bidAmount > scndBestBidAmount) {
                scndBestBidAmount = bid.bidAmount;
            }
        }
        assert(bestBid.bidAmount != 0);
        if (scndBestBidAmount == 0) {
            scndBestBidAmount = bestBid.bidAmount;
        }
        bestBid.bidAmount = scndBestBidAmount;
    }

    function storeBid(Bid memory bid) internal {
        string memory namespace = string(abi.encodePacked(BID_NAMESPACE, bid.poolId));
        address[] memory peekers = new address[](3);
        peekers[0] = address(this);
		peekers[1] = Suave.FETCH_DATA_RECORDS;
		peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
		Suave.DataRecord memory secretBid = Suave.newDataRecord(bid.blockNumber, peekers, peekers, namespace);
		Suave.confidentialStore(secretBid.id, namespace, abi.encode(bid));
    }

    function fetchBids(bytes32 pool, uint64 blockNumber) internal returns (Bid[] memory bids){
        string memory namespace = string(abi.encodePacked(BID_NAMESPACE, pool));
        Suave.DataRecord[] memory dataRecords = Suave.fetchDataRecords(blockNumber, namespace);
        for (uint i = 0; i < dataRecords.length; i++) {
            bytes memory bidBytes = Suave.confidentialRetrieve(dataRecords[i].id, namespace);
            Bid memory bid = abi.decode(bidBytes, (Bid));
            bids[i] = bid; 
        }
    }

    function storePK(bytes memory pk) internal returns (Suave.DataId) {
		address[] memory peekers = new address[](3);
		peekers[0] = address(this);
		peekers[1] = Suave.FETCH_DATA_RECORDS;
		peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
		Suave.DataRecord memory secretBid = Suave.newDataRecord(0, peekers, peekers, PK_NAMESPACE);
		Suave.confidentialStore(secretBid.id, PK_NAMESPACE, pk);
		return secretBid.id;
	}

    function retreivePK() internal returns (string memory) {
        bytes memory pkBytes =  Suave.confidentialRetrieve(pkBidId, PK_NAMESPACE);
        return string(pkBytes);
    }

}

// Utils 

function getAddressForPk(string memory pk) returns (address) {
    bytes32 digest = keccak256(abi.encode("yo"));
    bytes memory sig = Suave.signMessage(abi.encodePacked(digest), Suave.CryptoSignature.SECP256, pk);
    return recoverSigner(digest, sig);
}

function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) pure returns (address) {
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
    return ecrecover(_ethSignedMessageHash, v, r, s);
}

function splitSignature(bytes memory sig) pure returns (bytes32 r, bytes32 s, uint8 v) {
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