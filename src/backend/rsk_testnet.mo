import Types "Types";
import Debug "mo:base-0.7.3/Debug";
import Blob "mo:base-0.7.3/Blob";
import Cycles "mo:base-0.7.3/ExperimentalCycles";
import Error "mo:base-0.7.3/Error";
import Array "mo:base-0.7.3/Array";
import Nat8 "mo:base-0.7.3/Nat8";
import Nat64 "mo:base-0.7.3/Nat64";
import Text "mo:base-0.7.3/Text";
import Nat "mo:base-0.7.3/Nat";
import Int "mo:base-0.7.3/Int";
import List "mo:base-0.7.3/List";
import Iter "mo:base-0.7.3/Iter";
import Char "mo:base-0.7.3/Char";
import Principal "mo:base/Principal";
import JSON "mo:json/JSON";
import Buffer "mo:base-0.7.3/Buffer";
import Helper "mo:evm-tx/transactions/Helper";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";
import HU "mo:evm-tx/utils/HashUtils";
import Context "mo:evm-tx/Context";
import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";
import RLP "mo:rlp/hex/lib";
import Legacy "mo:evm-tx/transactions/Legacy";
import Transaction "mo:evm-tx/Transaction";
import PublicKey "mo:libsecp256k1/PublicKey";
import utils "utils";

module {
  type Event = {
    address : Text;
    amount : Nat;
  };

  type TransferEvent = {
     sendingChain : Text;
     recipientAddress : Text;
     recipientChain : Text;
     proofTxId : Text; // This will be the transaction where users send the funds to the canister contract address
  };

  type JSONField = (Text, JSON.JSON);

  let rskNodeUrl : Text = "https://rsk.getblock.io/437f13d7-2175-4d2c-a8c4-5e45ef6f7162/testnet/";

  let contractAddress : Text = "0x8F707cc9825aEE803deE09a05B919Ff33ace3A75";

  // ChainIds and Rpcs
  type Chain = {
    wbtcAddress : Text;
    rpcUrl: Text;
  };

  /*
  let rpcs = HashMap.HashMap<Text, Chain>(10,Text.equal, Text.hash);
  rpcs.put("0x1f",{
    wbtcAddress: "0x0",
    rpcUrl: "https://rsk.getblock.io/437f13d7-2175-4d2c-a8c4-5e45ef6f7162/testnet/"
  });

  rpcs.put("0x13881",{
    wbtcAddress: "0x0d787a4a1548f673ed375445535a6c7a1ee56180",
    rpcUrl: "https://rpc-mumbai.matic.today"
  });
  */


  /*
  public func swapFromLightningNetwork(hexChainId: Text,derivationPath : [Blob], keyName : Text, address : Text, amount : Nat, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let signerAddress = utils.publicKeyToAddress(publicKey);


    Debug.print("Recipient address: 0x" # address);

    Debug.print("Amount in wei to send" # Nat.toText(amount));

    if (signerAddress == "") {
      Debug.print("Could not get address!");
      return "";
    } else {
      Debug.print("Canister Address: 0x" # address);
    };

    // Building transactionData

    let method_sig = "transfer(address,uint256)";
    let keccak256_hex = AU.toText(HU.keccak(TU.encodeUtf8(method_sig), 256));
    let method_id = TU.left(keccak256_hex, 7);

    let address_64 = TU.fill(TU.right(address, 2), '0', 64);

    let amount_hex = AU.toText(AU.fromNat256(amount));
    let amount_256 = TU.fill(amount_hex, '0', 256);

    let data = "0x" #method_id # address_64 # amount_256;

    //Getting gas Price
    let gasPricePayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_gasPrice\", \"params\": [] }";
    let responseGasPrice : Text = await utils.httpRequest(?gasPricePayload, rpcUrl, null, "post", transform);
    let parsedGasPrice = JSON.parse(responseGasPrice);
    let gasPrice = await utils.getValue(parsedGasPrice, "result");

    //Estimating gas
    let estimateGasPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_estimateGas\", \"params\": [{ \"to\": \"" # wbtcAddress # "\", \"value\": \"" # "0x" # "00" # "\", \"data\": \"" # data # "\" }] }";
    let responseGas : Text = await utils.httpRequest(?estimateGasPayload,rpcUrl, null, "post", transform);
    let parsedGasValue = JSON.parse(responseGas);
    let gas = await utils.getValue(parsedGasValue, "result");

    //Getting nonce

    let noncePayLoad : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionCount\", \"params\": [\"" # signerAddress # "\", \"latest\"] }";
    let responseNoncepayLoad : Text = await utils.httpRequest(?noncePayLoad, rpcUrl, null, "post", transform);

    let parsedNonce = JSON.parse(responseNoncepayLoad);
    let nonce = await utils.getValue(parsedNonce, "result");

    let chainId = utils.hexStringToNat64(hexChainId);
    let target: Text = wbtcAddress;

    // Transaction details
    let transaction = {
      nonce = utils.hexStringToNat64(nonce);
      gasPrice = utils.hexStringToNat64(gasPrice);
      gasLimit = utils.hexStringToNat64(gas);
      to = target;
      value = 0;
      data = data;
      chainId = chainId;
      v = "0x00";
      r = "0x00";
      s = "0x00";
    };

    let ecCtx = Context.allocECMultContext(null);

    let serializedTx = await* Transaction.signTx(
      #Legacy(?transaction),
      chainId,
      keyName,
      derivationPath,
      publicKey,
      ecCtx,
      { create = IcEcdsaApi.create; sign = IcEcdsaApi.sign },
    );

    switch (serializedTx) {
      case (#ok value) {
        Debug.print("serializedTx: " # AU.toText(value.1));

        let sendTxPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"0x" # AU.toText(value.1) # "\"] }";
        Debug.print("Sending tx: " # sendTxPayload);

        let requestHeaders = [
          { name = "Content-Type"; value = "application/json" },
          { name = "Accept"; value = "application/json" },
          { name = "Idempotency-Key"; value = AU.toText(value.1) },
        ];
        let sendTxResponse : Text = await utils.httpRequest(?sendTxPayload, rpcUrl, ?requestHeaders, "post", transform);
        Debug.print("Tx response: " # sendTxResponse);
        return sendTxResponse;

      };
      case (#err errMsg) {
        Debug.print("Error: " # errMsg);
        return errMsg;
      };
    };

  };
  */
  public func readRSKSmartContractEvents(transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async [Event] {

    let ic : Types.IC = actor ("aaaaa-aa");

    // Topic for encoded keccack-256 hash of SwapToLightningNetwork event
    let topics : [Text] = ["0xd7064750d0bfcc43414a0eaf761384271b3f77200c7ad833cc059d015b5e12a7", "0x0000000000000000000000005d6235587677478b75bd088f7730abdcc2c39110"];

    let blockNumber : Text = "0x409492"; // We will filter after the contract creation

    let jsonRpcPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getLogs\", \"params\": [{ \"address\": \"" # contractAddress # "\", \"fromBlock\": \"" # blockNumber # "\", \"topics\": " # encodeTopics(topics) # " }] }";

    let decodedText = await utils.httpRequest(?jsonRpcPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/getEvents", null, "post", transform);

    let events = await handleLogs(decodedText);

    return events;
  };

  public func swapEVM2EVM(hexChainId: Text,transferEvent : TransferEvent, derivationPath : [Blob], keyName : Text,  transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {

    let recipientAddr = transferEvent.recipientAddress;
    let recipientChainId = transferEvent.recipientChain;
    let sendingChainId = transferEvent.sendingChain;
    let transactionId = transferEvent.proofTxId;

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let signerAddress = utils.publicKeyToAddress(publicKey);

    Debug.print("Recipient address: 0x" # recipientAddr);
    Debug.print("recipientChainId" # recipientChainId);
    Debug.print("sendingChainId" # sendingChainId);

    if (signerAddress == "") {
      Debug.print("Could not get address!");
      return "";
    } else {
      Debug.print("Canister Address: 0x" # signerAddress);
    };

    //We will check the transactionId on the sendingChain to see if he sent any money

    // Fetch transaction details using transactionId
    let transactionDetailsPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionByHash\", \"params\": [\"" # transactionId # "\"] }";
    let responseTransactionDetails : Text = await utils.httpRequest(?transactionDetailsPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", null, "post", transform);
    let parsedTransactionDetails = JSON.parse(responseTransactionDetails);

    // Not sure if it is to here
    let transactionProof = await utils.getValue(parsedTransactionDetails, "to");

    let transactionAmount = await utils.getValue(parsedTransactionDetails, "amount");

    // Check if the recipient address and amount in the transaction match your criteria
    if (transactionProof == signerAddress) {
      return await createAndSendTransaction(
        "0x000", //to test later
        derivationPath,
        keyName,
        signerAddress,
        recipientAddr,
        transactionAmount,
        publicKey,
        transform,
      );
    } else {
      Debug.print("Transaction does not match the criteria");
      return "Not valid transaction";
    };

  };

  public func swapLN2EVM(hexChainId: Text,derivationPath : [Blob], keyName : Text,  amount : Text, recipientAddr:Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {
    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let signerAddress = utils.publicKeyToAddress(publicKey);

    return await createAndSendTransaction(
      hexChainId,
      derivationPath,
      keyName,
      signerAddress,
      recipientAddr,
      amount,
      publicKey,
      transform,
    );

  };


  private func createAndSendTransaction(hexChainId: Text,derivationPath : [Blob], keyName  : Text, signerAddress : Text, recipientAddr : Text, transactionAmount : Text, publicKey : [Nat8], transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {
    // here check the transactionId, if he sent the money to our canister Address, save the amount

    // Now transactionAmount is a Nat and can be used in further calculations

    // This will be now a transaction without data

    // let method_sig = "swapFromLightningNetwork(address,uint256)";
    // let keccak256_hex = AU.toText(HU.keccak(TU.encodeUtf8(method_sig), 256));
    // let method_id = TU.left(keccak256_hex, 7);
    // let address_64 = TU.fill(address, '0', 64);
    // let amount_hex = AU.toText(AU.fromNat256(amount));
    // let amount_64 = TU.fill(amount_hex, '0', 64);

    // let data = "0x" # method_id # address_64 # amount_64;

    //Getting gas Price
    let gasPricePayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_gasPrice\", \"params\": [] }";
    let responseGasPrice : Text = await utils.httpRequest(?gasPricePayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", null, "post", transform);
    let parsedGasPrice = JSON.parse(responseGasPrice);
    let gasPrice = await utils.getValue(parsedGasPrice, "result");

    //Estimating gas
    let estimateGasPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_estimateGas\", \"params\": [{ \"to\": \"" # recipientAddr # "\", \"value\": \"" # "0x" # "00" # "\", \"data\": \"" # "0x00" # "\" }] }";
    let responseGas : Text = await utils.httpRequest(?estimateGasPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", null, "post", transform);
    let parsedGasValue = JSON.parse(responseGas);
    let gas = await utils.getValue(parsedGasValue, "result");

    //Getting nonce

    let noncePayLoad : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionCount\", \"params\": [\"" # signerAddress # "\", \"latest\"] }";
    let responseNoncepayLoad : Text = await utils.httpRequest(?noncePayLoad, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", null, "post", transform);

    let parsedNonce = JSON.parse(responseNoncepayLoad);
    let nonce = await utils.getValue(parsedNonce, "result");

    let chainId = utils.hexStringToNat64(hexChainId);

    // Transaction details
    let transaction = {
      nonce = utils.hexStringToNat64(nonce);
      gasPrice = utils.hexStringToNat64(gasPrice);
      gasLimit = utils.hexStringToNat64(gas);
      to = recipientAddr;
      value = Nat64.toNat(utils.hexStringToNat64(transactionAmount));
      data = "0x00";
      chainId = chainId;
      v = "0x00";
      r = "0x00";
      s = "0x00";
    };

    let ecCtx = Context.allocECMultContext(null);

    let serializedTx = await* Transaction.signTx(
      #Legacy(?transaction),
      chainId,
      keyName,
      derivationPath,
      publicKey,
      ecCtx,
      { create = IcEcdsaApi.create; sign = IcEcdsaApi.sign },
    );

    switch (serializedTx) {
      case (#ok value) {
        Debug.print("serializedTx: " # AU.toText(value.1));

        let sendTxPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"0x" # AU.toText(value.1) # "\"] }";
        Debug.print("Sending tx: " # sendTxPayload);

        let requestHeaders = [
          { name = "Content-Type"; value = "application/json" },
          { name = "Accept"; value = "application/json" },
          { name = "Idempotency-Key"; value = AU.toText(value.1) },
        ];
        let sendTxResponse : Text = await utils.httpRequest(?sendTxPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/payBlockchainTx", ?requestHeaders, "post", transform);
        Debug.print("Tx response: " # sendTxResponse);
        return sendTxResponse;

      };
      case (#err errMsg) {
        Debug.print("Error: " # errMsg);
        return errMsg;
      };
    };

  };

  private func encodeTopics(topics : [Text]) : Text {
    let joinedTopics = Array.foldLeft<Text, Text>(
      topics,
      "",
      func(acc, topic) {
        if (acc == "") {
          "\"" # topic # "\"";
        } else {
          acc # "," # "\"" # topic # "\"";
        };
      },
    );
    return "[" # joinedTopics # "]";
  };

  private func handleLogs(decodedText : Text) : async [Event] {
    Debug.print("Decoded Text: " # decodedText);

    let parsedJson = JSON.parse(decodedText);

    switch (parsedJson) {
      case (null) {
        Debug.print("JSON parsing failed.");
        return [];
      };
      case (?parsedObj) {
        switch (parsedObj) {
          case (#Object(fields)) {
            let resultField = Array.find(fields, func((k : Text, _ : JSON.JSON)) : Bool { k == "result" });
            switch (resultField) {
              case (null) {
                Debug.print("Result field not found.");
                return [];
              };
              case (?(_, #Array(logArray))) {
                Debug.print("Processing logs: " # JSON.show(#Array(logArray)));
                return await processLog(JSON.show(#Array(logArray)));
              };
              case (_) {
                Debug.print("Result field is not an array or not found");
                return [];
              };
            };
          };
          case (_) {
            Debug.print("JSON parsing did not produce an object");
            return [];
          };
        };
      };
    };
  };

  private func processLog(logText : Text) : async [Event] {
    Debug.print("Input logText: " # logText);

    var events : [Event] = [];

    let parsedJSON = JSON.parse(logText);

    //Refactor this switch
    switch (parsedJSON) {
      case (null) {
        Debug.print("JSON parsing failed");
      };
      case (?v) switch (v) {
        case (#Array(logArray)) {

          for (log in logArray.vals()) {
            Debug.print("Processing log: " # JSON.show(log));

            switch (log) {
              case (#Object(logFields)) {

                let finalAddress = await utils.getFieldAsString(logFields, "address");
                let data0x = await utils.getFieldAsString(logFields, "data");
                let data = utils.subText(data0x, 3, data0x.size() -1);

                Debug.print("data: " # data);

                let dataBytes = AU.fromText(data);
                let amountBytes = AU.slice(dataBytes, 0, 32);

                let amount = AU.toNat256(amountBytes);
                let invoiceIdHexBytes = AU.slice(dataBytes, 80, dataBytes.size() - 80);

                let invoiceIdHexString = AU.toText(invoiceIdHexBytes);
                let invoiceIdBytes = AU.fromText(invoiceIdHexString);
                let invoiceId = await utils.bytes32ToString(invoiceIdHexString);

                switch (invoiceId) {
                  case (null) {
                    Debug.print("Failed to decode invoiceId");
                  };
                  case (?invoiceIdString) {

                    let invoiceTrim = Text.replace(invoiceIdString, #char ',', "");

                    let newEvent : Event = {
                      address = invoiceTrim;
                      amount = amount;
                    };
                    events := Array.append(events, [newEvent]);
                  };
                };

              };
              case _ { Debug.print("Unexpected JSON structure") };
            };
          };
        };
        case _ { Debug.print("Parsed JSON is not an array") };
      };
    };
    return events;
  };
};
