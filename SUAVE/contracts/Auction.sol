pragma solidity ^0.8.9;

import "./lib/SuaveContract.sol";
import "lib/solady/src/utils/LibString.sol";
import "lib/solady/src/utils/JSONParserLib.sol";

import "../lib/forge-std/src/Test.sol"; // todo: rm for prod

contract Auction is SuaveContract {
    using JSONParserLib for *;

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

    uint constant BEACON_MAINNET_GENISIS_TIME = 1606824023;
    string constant PK_NAMESPACE = "auction:v0:pksecret";
    string constant BID_NAMESPACE = "auction:v0:bids";
    address public immutable registry;
    string public settlementChainRpc;
    address public internalWallet;
    uint64 public lastAuctionBlock;
    bool public isInitialized;
    Suave.DataId internal pkBidId;
    address[] public genericPeekers = [0xC8df3686b4Afb2BB53e60EAe97EF043FE03Fb829]; // todo: rm after new update (this exposes to anyone)
    uint maxSettledAuctionBlock;

    // ⛓️ EVM Methods

    constructor(address _registry, string memory _settlementChainRpc) {
        settlementChainRpc = _settlementChainRpc;
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
        maxSettledAuctionBlock = winningBid.blockNumber;
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

    function confidentialConstructor() external returns (bytes memory) {
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
        require(bidAmount > 0, "Bid amount should be greater than zero");
        require(checkSufficientFundsLocked(pool, poolId, bidder, bidAmount), "Insufficient funds locked");
        storeBid(Bid(pool, poolId, blockNumber, bidder, bidAmount));

        return abi.encodeWithSelector(
            this.submitBidCallback.selector, 
            Bid(pool, poolId, blockNumber, bidder, bidAmount)
        );
    }

    function checkSufficientFundsLocked(
        address pool, 
        bytes32 poolId,
        address user, 
        uint bidAmount
    ) public view returns (bool) {
        bytes memory callData = abi.encodeWithSignature(
            "hasSufficientFundsToPayforOrdering(address,bytes32,address,address,uint256)",
            pool,
            poolId,
            user, 
            address(0), 
            bidAmount
        );
        string memory callParam = string(abi.encodePacked(
            '{"to": "', LibString.toHexStringChecksummed(registry), 
            '","data": "', LibString.toHexString(callData),'"}'
        ));
        bytes memory response = ethCall(callParam);

        JSONParserLib.Item memory parsedRes = string(response).parse();
        string memory result = string(parsedRes.at('"result"').value());
        bool boolRes = LibString.endsWith(result, '1"'); // todo there is a better way

        return boolRes;
    }

    function ethCall(string memory callParam) public view returns (bytes memory) {
        bytes memory body = abi.encodePacked(
            '{"jsonrpc":"2.0","method":"eth_call","params":[', 
            callParam, ', "latest"'
            '],"id":1}'
        );
        Suave.HttpRequest memory request;
        request.method = "POST";
        request.body = body;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        request.withFlashbotsSignature = false;
        request.url = settlementChainRpc;
        return doHttpRequest(request);
    }

    function slotToBlockNumber(uint slot) public view returns (uint64) {
        string memory beaconBaseUrl = "https://docs-demo.quiknode.pro/eth/v2/beacon/blocks/";
        string memory url = string(abi.encodePacked(beaconBaseUrl, LibString.toString(slot)));
        Suave.HttpRequest memory request;
        request.method = "GET";
        request.url = url;
        request.withFlashbotsSignature = false;
        request.headers = new string[](1);
        request.headers[0] = "Content-Type: application/json";
        bytes memory response = doHttpRequest(request);
        JSONParserLib.Item memory parsedRes = string(response).parse();
        string memory blockNumber = string(parsedRes.at('"data"').at('"message"').at('"body"').at('"execution_payload"').at('"block_number"').value());
        uint blockNum = JSONParserLib.parseUint(trimStrEdges(blockNumber));
        return uint64(blockNum);
    }

    function doHttpRequest(Suave.HttpRequest memory request) internal view returns (bytes memory) {
        (bool success, bytes memory data) = Suave.DO_HTTPREQUEST.staticcall(abi.encode(request));
        // console.log(success);
        // console.logBytes(data);
        crequire(success, string(data));
        return abi.decode(data, (bytes));
    }

    function settleAuction(address pool, bytes32 poolId, uint64 blockNumber, uint nextSlot) public returns (bytes memory) {
        checkForValidSettlement(nextSlot, blockNumber);
        Bid[] memory bids = fetchBids(pool, poolId, blockNumber);
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

    function checkForValidSettlement(uint nextSlot, uint settlementBlock) internal view {
        require(settlementBlock > maxSettledAuctionBlock);
        uint nextBlockNum = slotToBlockNumber(nextSlot);
        require(nextBlockNum == settlementBlock, "Wrong slot");
        uint nextSlotTimestamp = timestampForSlot(nextSlot);
        require(block.timestamp < nextSlotTimestamp-10, "Slot not closed yet");
    }

    function timestampForSlot(uint slot) public pure returns (uint) {
        return BEACON_MAINNET_GENISIS_TIME + slot * 12;
    }

    function signBid(Bid memory bid) public returns (bytes memory sig) {
        string memory pk = retreivePK();
        bytes32 digest = keccak256(abi.encode(bid));
        console.log("Digest:"); // todo: rm
        console.logBytes32(digest); // todo: rm
        sig = Suave.signMessage(abi.encodePacked(digest), Suave.CryptoSignature.SECP256, pk);
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
        string memory namespace = string(abi.encodePacked(BID_NAMESPACE, bid.pool, bid.poolId));
        address[] memory peekers = new address[](3);
        peekers[0] = address(this);
		peekers[1] = Suave.FETCH_DATA_RECORDS;
		peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
		Suave.DataRecord memory secretBid = Suave.newDataRecord(bid.blockNumber, genericPeekers, genericPeekers, namespace);
		Suave.confidentialStore(secretBid.id, namespace, abi.encode(bid));
    }

    function fetchBids(
        address pool, 
        bytes32 poolId, 
        uint64 blockNumber
    ) public returns (Bid[] memory){
        string memory namespace = string(abi.encodePacked(BID_NAMESPACE, pool, poolId));
        Suave.DataRecord[] memory dataRecords = Suave.fetchDataRecords(blockNumber, namespace);
        Bid[] memory bids = new Bid[](dataRecords.length);
        for (uint i = 0; i < dataRecords.length; i++) {
            bytes memory bidBytes = Suave.confidentialRetrieve(dataRecords[i].id, namespace);
            Bid memory bid = abi.decode(bidBytes, (Bid));
            bids[i] = bid;
        }
        return bids;
    }

    function storePK(bytes memory pk) internal returns (Suave.DataId) {
		address[] memory peekers = new address[](3);
		peekers[0] = address(this);
		peekers[1] = Suave.FETCH_DATA_RECORDS;
		peekers[2] = Suave.CONFIDENTIAL_RETRIEVE;
		Suave.DataRecord memory secretBid = Suave.newDataRecord(0, genericPeekers, genericPeekers, PK_NAMESPACE);
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

function trimStrEdges(string memory _input) pure returns (string memory) {
    bytes memory input = bytes(_input);
    require(input.length > 2, "Input too short");

    uint newLength = input.length - 2;
    bytes memory result = new bytes(newLength);

    assembly {
        let inputPtr := add(input, 0x21)
        let resultPtr := add(result, 0x20)
        let length := mload(input)
        mstore(resultPtr, mload(inputPtr))
        mstore(result, newLength)
    }
    return string(result);
}