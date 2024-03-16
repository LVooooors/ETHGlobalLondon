pragma solidity ^0.8.9;


contract VickyLVRHookup {

    // ⛓️ EVM Methods

    function confidentialConstructorCallback(
        Suave.DataId _pkBidId, 
        address pkAddress
    ) public {
        crequire(!isInitialized, "Already initialized");
        pkBidId = _pkBidId;
        controller = pkAddress;
        isInitialized = true;
    }

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

    // permenant confidential state: hosts pk and the associate address
    //  

    function confidentialConstructor() public {
        // retreive pk 
    }

    // store bid 
    function bid(address pool, uint blockNumber, uint bid) public {
        address bidder = msg.sender;
        // Call settlement chain to check if the bidder has enough funds to bid
        // Store bid in sstore
    }

    function resolveAuction() public {
        // Check if this is appropriate time to resolve auction
        // Fetch all the bids related to a label from a sstore
        // Go over all the bids and determine the winner and the bid of the scnd best
        // Sign: winnerAdd, scndBidAmount, pool, block
    }

}