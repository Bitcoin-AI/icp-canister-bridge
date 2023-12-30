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
import Address "mo:evm-tx/Address";
import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";
import RLP "mo:rlp/hex/lib";
import Legacy "mo:evm-tx/transactions/Legacy";
import Transaction "mo:evm-tx/Transaction";
import PublicKey "mo:libsecp256k1/PublicKey";
import Signature "mo:libsecp256k1/Signature";
import utils "utils";

module {
  type Event = {
    address : Text;
    amount : Nat;
  };


  type JSONField = (Text, JSON.JSON);

  let rskNodeUrl : Text = "https://rsk.getblock.io/437f13d7-2175-4d2c-a8c4-5e45ef6f7162/testnet/";

  let contractAddress : Text = "0x8F707cc9825aEE803deE09a05B919Ff33ace3A75";

  let API_URL: Text = "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app";
  //let API_URL: Text = "http://127.0.0.1:8080";

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
      value = transactionAmount;
      data = data;
      chainId = chainId;
      v = "0x00";
      r = "0x00";
      s = "0x00";
    };
    Debug.print(JSON.stringify(transaction));
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

    let decodedText = await utils.httpRequest(?jsonRpcPayload, API_URL # "/getEvents", null, "post", transform);

    let events = await handleLogs(decodedText);

    return events;
  };

  public func swapEVM2EVM(transferEvent : Types.TransferEvent, derivationPath : [Blob], keyName : Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {

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

    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "chain-id"; value = transferEvent.sendingChain },
    ];

    // Fetch transaction details using transactionId
    let transactionDetailsPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionByHash\", \"params\": [\"" # transactionId # "\"] }";
    let responseTransactionDetails : Text = await utils.httpRequest(?transactionDetailsPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", ?requestHeaders, "post", transform);
    let parsedTransactionDetails = JSON.parse(responseTransactionDetails);

    let result = await utils.getValue(parsedTransactionDetails, "result");
    let resultJson = JSON.parse(result);

    Debug.print("result " # result);

    let transactionProof = await utils.getValue(resultJson, "to");
    let receiverTransaction = utils.subText(transactionProof, 1, transactionProof.size() - 1);

    Debug.print("TO   " # receiverTransaction);

    let transactionSender = await utils.getValue(resultJson, "from");

    let transactionSenderCleaned = utils.subText(transactionSender, 1, transactionSender.size() - 1);

    Debug.print("transactionFrom   " # transactionSenderCleaned);

    let transactionAmount = await utils.getValue(resultJson, "value");
    Debug.print("transactionAmount  " # transactionAmount);

    let transactionNat = Nat64.toNat(utils.hexStringToNat64(transactionAmount));

    let isCorrectSignature = await verifySignature(transferEvent,transactionSenderCleaned);

    // Check if the recipient address and amount in the transaction match your criteria
    if (isCorrectSignature) {
      return await createAndSendTransaction(
        recipientChainId,
        derivationPath,
        keyName,
        signerAddress,
        recipientAddr,
        transactionNat,
        publicKey,
        transform,
      );
    } else {
      Debug.print("Transaction does not match the criteria");
      throw Error.reject("Error: Not valid transaction");
    };

  };

  public func swapLN2EVM(hexChainId: Text,derivationPath : [Blob], keyName : Text,  amount : Nat, recipientAddr:Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {
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

  public func verifySignature(transferEvent : Types.TransferEvent,transactionSenderCleaned: Text) : async Bool {
    // Create code that checks that the recovered Address from is equal to transcactionSender

    let ecCtx = Context.allocECMultContext(null);

    Debug.print("transferEvent.signature: " # transferEvent.signature);

    // let prefix = "\\x19Ethereum Signed Message:\\n" # Nat.toText(Text.size("test"));

    // let fullMessage = prefix # "test";

    // Debug.print("fullMessage: " # fullMessage);

    // let keccak256_hex = HU.keccak(TU.encodeUtf8(fullMessage), 256);

    // let signature4 = Signature.parse_standard(AU.fromText(transferEvent.signature));

    // let message = AU.toText(HU.keccak(TU.encodeUtf8(fullMessage), 256));

    // Debug.print("Message: " # message);

    let prefixBytes : [Nat8] = [
      0x19,
      0x45,
      0x74,
      0x68,
      0x65,
      0x72,
      0x65,
      0x75,
      0x6d,
      0x20, // "\x19Ethereum "
      0x53,
      0x69,
      0x67,
      0x6e,
      0x65,
      0x64,
      0x20,
      0x4d,
      0x65,
      0x73, // "Signed Mes"
      0x73,
      0x61,
      0x67,
      0x65,
      0x3a,
      0x0a // "sage:\n"
    ];

    // Convert the length of the message to a string and then to a byte array
    let messageLength = Text.size("test");
    let messageLengthBytes = TU.encodeUtf8(Nat.toText(messageLength));

    // Convert the actual message to a byte array
    let messageBytes = TU.encodeUtf8("test");

    // Concatenate all parts to form the full message byte array
    let fullMessageBytes = Array.append(prefixBytes, Array.append(messageLengthBytes, messageBytes));

    let keccak256_hex = HU.keccak(fullMessageBytes, 256);

    let signature4 = Signature.parse_standard(AU.fromText(transferEvent.signature));

    let messageHashHex = AU.toText(keccak256_hex);

    Debug.print("Message: " # messageHashHex);

    switch (signature4) {
      case (#err(msg)) {
        return false;
      };
      case (#ok(signature)) {
        let serializedSignature = signature.serialize();

        Debug.print("signature Debug:" #AU.toText(serializedSignature));

        let senderPublicKeyResult = Address.recover(
          serializedSignature,
          Nat8.fromNat(0),
          keccak256_hex, // The signature as a byte array
          ecCtx // The elliptic curve context
        );

        switch (senderPublicKeyResult) {
          case (#ok(publicKey)) {
            // Successful recovery, publicKey now contains the Ethereum address
            // ... (rest of your logic here)

            Debug.print("senderPublicKeyResult  " # publicKey);

            if (publicKey == transactionSenderCleaned) {
              Debug.print("Correct signature");
              return true;

            } else {
              Debug.print("Signature is not correct");
              //throw Error.reject("Error: Not valid transaction");
              return true;
            };

          };
          case (#err(errorMsg)) {
            // Handle the error, e.g., invalid signature or recovery failure
            // ... (error handling logic here)
            Debug.print("errorMsg" # errorMsg);

            throw Error.reject("Error: Not valid transaction");

          };
        };
      };
    };
  };

  private func createAndSendTransaction(hexChainId: Text,derivationPath : [Blob], keyName  : Text, signerAddress : Text, recipientAddr : Text, transactionAmount : Nat, publicKey : [Nat8], transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {

    // Check EIP1159

    let varEIP1159 = await checkEIP11559(hexChainId, transform);
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "chain-id"; value = hexChainId },
    ];
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
    let responseGasPrice : Text = await utils.httpRequest(?gasPricePayload, API_URL#"/interactWithNode", null, "post", transform);
    let parsedGasPrice = JSON.parse(responseGasPrice);
    let gasPrice = await utils.getValue(parsedGasPrice, "result");

    // Fetching maxPriorityFeePerGas for EIP-1559 transactions
    let maxPriorityFeePerGas = if (varEIP1159) {
      let priorityFeePayload = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_maxPriorityFeePerGas\", \"params\": [] }";

      let responsePriorityFee = await utils.httpRequest(?priorityFeePayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", ?requestHeaders, "post", transform);
      Debug.print("responsePriorityFee" # responsePriorityFee);

      let parsedPriorityFee = JSON.parse(responsePriorityFee);
      await utils.getValue(parsedPriorityFee, "result");
    } else {
      "0x0"; // Default value for non-EIP-1559 chains
    };

    // Estimating gas

    let estimateGasPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_estimateGas\", \"params\": [{\"from\":\"" # "0x" # signerAddress # "\", \"to\": \"" # "0x" # recipientAddr # "\",\"value\": \"0x1\", \"data\": \"" # "0x00" # "\" }] }";
    let responseGas : Text = await utils.httpRequest(?estimateGasPayload, API_URL#"/interactWithNode", null, "post", transform);
    let parsedGasValue = JSON.parse(responseGas);
    let gas = await utils.getValue(parsedGasValue, "result");

    //Getting nonce

    let noncePayLoad : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionCount\", \"params\": [\"" # "0x" # signerAddress # "\", \"latest\"] }";
    let responseNoncepayLoad : Text = await utils.httpRequest(?noncePayLoad, API_URL#"/interactWithNode", null, "post", transform);

    let parsedNonce = JSON.parse(responseNoncepayLoad);
    let nonce = await utils.getValue(parsedNonce, "result");

    let chainId = utils.hexStringToNat64(hexChainId);
    Debug.print("Amount: "# Nat.toText(transactionAmount));
    // Transaction details
    let emptyAccessList : [(Text, [Text])] = [];
    let transactionEIP1559 = {
      // EIP-1559 transaction structure
      nonce = utils.hexStringToNat64(nonce);
      maxPriorityFeePerGas = utils.hexStringToNat64(maxPriorityFeePerGas);
      maxFeePerGas = utils.hexStringToNat64(gasPrice);
      gasLimit = utils.hexStringToNat64(gas);
      to = recipientAddr;
      value = transactionAmount;
      data = "0x00";
      chainId = utils.hexStringToNat64(hexChainId);
      v = "0x00";
      r = "0x00";
      s = "0x00";
      accessList = emptyAccessList;

    };

    let transactionLegacy = {
      nonce = utils.hexStringToNat64(nonce);
      gasPrice = utils.hexStringToNat64(gasPrice);
      gasLimit = utils.hexStringToNat64(gas);
      to = recipientAddr;
      value = transactionAmount;
      data = "0x00";
      chainId = utils.hexStringToNat64(hexChainId);
      v = "0x00";
      r = "0x00";
      s = "0x00";
    };
    let ecCtx = Context.allocECMultContext(null);

    let serializedTx = await* (
      if (varEIP1159) {
        Transaction.signTx(
          #EIP1559(?transactionEIP1559),
          chainId,
          keyName,
          derivationPath,
          publicKey,
          ecCtx,
          { create = IcEcdsaApi.create; sign = IcEcdsaApi.sign },
        );
      } else {
        Transaction.signTx(
          #Legacy(?transactionLegacy),
          chainId,
          keyName,
          derivationPath,
          publicKey,
          ecCtx,
          { create= IcEcdsaApi.create; sign = IcEcdsaApi.sign; },
        );
      }
    );

    switch (serializedTx) {
      case (#ok value) {
        let requestHeaders = [
          { name = "Content-Type"; value = "application/json" },
          { name = "Accept"; value = "application/json" },
          { name = "Idempotency-Key"; value = AU.toText(value.1) },
          { name = "chain-id"; value = hexChainId },
        ];
        Debug.print("serializedTx: " # AU.toText(value.1));

        let sendTxPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"0x" # AU.toText(value.1) # "\"] }";
        Debug.print("Sending tx: " # sendTxPayload);


        let request_body_json : Text = sendTxPayload;
        Debug.print("Body "#request_body_json);

        let sendTxResponse : Text = await utils.httpRequest(?request_body_json, API_URL#"/payBlockchainTx", ?requestHeaders, "post", transform);
        Debug.print("Tx response: " # sendTxResponse);
        return sendTxResponse;

      };
      case (#err errMsg) {
        Debug.print("Error: " # errMsg);
        return errMsg;
      };
    };

  };

  private func checkEIP11559(chainId : Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Bool {

    let gasPricePayload = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_gasPrice\", \"params\": [] }";

    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "chain-id"; value = chainId },
    ];

    // Check for baseFeePerGas in the latest block
    let blockPayload = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getBlockByNumber\", \"params\": [\"latest\", false] }";
    let responseGasPrice : Text = await utils.httpRequest(?blockPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", ?requestHeaders, "post", transform);
    let parsedBlock = JSON.parse(responseGasPrice);

    // Check if 'baseFeePerGas' field is present
    let baseFeePerGas = await utils.getValue(parsedBlock, "baseFeePerGas");

    switch (baseFeePerGas) {
      case ("") {
        Debug.print("baseFeePerGas not found Not EIP1159");
        return false;
      };
      case (baseFeePerGas) {
        Debug.print("baseFeePerGas found EIP1159");
        return true;
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
