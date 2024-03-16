pragma solidity ^0.8.9;


import "./lib/SuaveContract.sol";


contract VickyLVRHookup {

    struct Bid {
        address bidder;
        address pool;
        uint blockNumber;
        uint bidAmount;
    }

    string constant PK_NAMESPACE = "auction:v0:pksecret";
    string constant BID_NAMESPACE = "auction:v0:bids";
    address internalWallet;
    address settlementVault;
    bool isInitialized;

    // ⛓️ EVM Methods

    constructor(address _escrow) {
        escrow = _escrow;
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

    // todo: bid callback

    // 🤐 MEVM Methods

    function confidentialConstructor() external view onlyConfidential returns (bytes memory) {
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

    function bid(address pool, uint blockNumber, uint bidAmount) public {
        address bidder = msg.sender;
        // todo: Call settlement chain to check if the bidder has enough funds to bid

        storeBid(Bid(bidder, pool, blockNumber, bidAmount));
    }

    function settleAuction(address pool, uint blockNumber) public {
        Bids[] memory bids = fetchBids(pool, blockNumber);
        (Bid memory winningBid) = bids.length == 0
            ? Bid(address(0), pool, blockNumber, 0)
            : findWinningBid(bids);

        bytes memory sig = signBid(winningBid);
        
    }

    function signBid(Bid memory bid) public returns (bytes memory sig) {
        string memory pk = retreivePK();
        sig = Suave.signMessage(abi.encodePacked(bid), Suave.CryptoSignature.SECP256, pk);
    }

    function findWinningBid(Bid[] memory bids) internal view returns (Bid memory bestBid) {
        uint scndBestBidAmount;
        for (uint i = 0; i < dataRecords.length; i++) {
            Bid memory bid = bids[i];
            if (bid.bidAmount > bestBid.bidAmount) {
                scndBestBidAmount = bestBid.bidAmount;
                bestBid = bid;
            } else if (bid.bidAmount > scndBestBidAmount) {
                scndBestBidAmount = bid.bid;
            }
        }
        if (bestBid.bidAmount == 0) {
            revert("No bids found"); // todo: if no bids then bidder is zero and payment as well
        }
        if (scndBestBidAmount == 0) {
            scndBestBidAmount = bestBid.bidAmount;
        }
        bestBid.bidAmount = scndBestBidAmount;
    }

    function storeBid(Bid memory bid) internal {
        string memory namespace = string memory namespace = string(abi.encodePacked(BID_NAMESPACE, pool));
        address[] memory peekers = new address[](3);
        peekers[0] = address(this);
		peekers[1] = Suave.FETCH_DATA_RECORDS;
		peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
		Suave.DataRecord memory secretBid = Suave.newDataRecord(bid.blockNumber, peekers, peekers, namespace);
		Suave.confidentialStore(secretBid.id, namespace, abi.encode(bid));
    }

    function fetchBids(address pool, uint blockNumber) internal view returns (Bid memory bids){
        string memory namespace = string(abi.encodePacked(BID_NAMESPACE, pool));
        Suave.DataRecord[] memory dataRecords = Suave.fetchDataRecords(blockNumber, namespace);
        for (uint i = 0; i < dataRecords.length; i++) {
            bytes memory bidBytes = Suave.confidentialRetrieve(dataRecords[i].id, namespace);
            Bid memory bid = abi.decode(bidBytes, (Bid));
            bids[i] = bid; 
        }
    }

    function storePK(bytes memory pk) internal view returns (Suave.DataId) {
		address[] memory peekers = new address[](3);
		peekers[0] = address(this);
		peekers[1] = Suave.FETCH_DATA_RECORDS;
		peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
		Suave.DataRecord memory secretBid = Suave.newDataRecord(0, peekers, peekers, PK_NAMESPACE);
		Suave.confidentialStore(secretBid.id, PK_NAMESPACE, pk);
		return secretBid.id;
	}

    function retreivePK() internal view returns (string memory) {
        bytes memory pkBytes =  Suave.confidentialRetrieve(pkBidId, PK_NAMESPACE);
        return string(pkBytes);
    }


    // Utils 

    function getAddressForPk(string memory pk) view returns (address) {
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

}