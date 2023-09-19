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

actor {

  type Event = {
    address : Text;
  };

  type JSONField = (Text, JSON.JSON);

  let rskNodeUrl : Text = "https://rsk.getblock.io/437f13d7-2175-4d2c-a8c4-5e45ef6f7162/testnet/";

  let contractAddress : Text = "0x953CD84Bb669b42FBEc83AD3227907023B5Fc4FF";


  // TODO :
  // This function will only be callable by the alby_mo function `checkInvoices` that  will decide
  // which user should be be paid in RSK, by adding balance in the Smart Contract
  // Check how to do access control e.g. This canister function can only called by the alby canister 
  // Right now it will be maintained as public for testing.
  public shared (msg) func swapToLightningNetwork() : async Text {

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let address = utils.publicKeyToAddress(publicKey);

    if (address == "") {
      Debug.print("Could not get address!");
      return "";
    } else {
      Debug.print("Address: 0x" # address);
    };

    // Building transactionData

    let method_sig = "swapFromLightningNetwork(address,uint256)";
    let keccak256_hex = AU.toText(HU.keccak(TU.encodeUtf8(method_sig), 256));
    let method_id = TU.left(keccak256_hex, 7);
    let address_64 = TU.fill(address, '0', 64);
    let amount_hex = AU.toText(AU.fromNat256(1000));
    let amount_64 = TU.fill(amount_hex, '0', 64);

    let data = "0x" # method_id # address_64 # amount_64;

    //Getting gas Price
    let gasPricePayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_gasPrice\", \"params\": [] }";
    let responseGasPrice : Text = await utils.httpRequest(?gasPricePayload, rskNodeUrl, null, "post");
    let parsedGasPrice = JSON.parse(responseGasPrice);
    let gasPrice = await getValue(parsedGasPrice);

    //Estimating gas
    let estimateGasPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_estimateGas\", \"params\": [{ \"to\": \"" # contractAddress # "\", \"value\": \"" # "0x" # "00" # "\", \"data\": \"" # data # "\" }] }";
    let responseGas : Text = await utils.httpRequest(?estimateGasPayload, rskNodeUrl, null, "post");
    let parsedGasValue = JSON.parse(responseGas);
    let gas = await getValue(parsedGasValue);

    //Getting nonce

    let noncePayLoad : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionCount\", \"params\": [\"" # address # "\", \"latest\"] }";
    let responseNoncepayLoad : Text = await utils.httpRequest(?noncePayLoad, rskNodeUrl, null, "post");

    let parsedNonce = JSON.parse(responseNoncepayLoad);
    let nonce = await getValue(parsedNonce);

    let chainId = utils.hexStringToNat64("0x1f");

    // Transaction details
    let transaction = {
      nonce = utils.hexStringToNat64(nonce);
      gasPrice = utils.hexStringToNat64(gasPrice);
      gasLimit = utils.hexStringToNat64(gas);
      to = contractAddress;
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
        let sendTxResponse : Text = await utils.httpRequest(?sendTxPayload, rskNodeUrl, null, "post");
        Debug.print("Tx response: " # sendTxResponse);

        return sendTxResponse;

      };
      case (#err errMsg) {
        Debug.print("Error: " # errMsg);
        return errMsg;
      };
    };

  };

  private func getValue(parsedGasPrice : ?JSON.JSON) : async Text {
    switch (parsedGasPrice) {
      case (null) {
        Debug.print("JSON parsing failed");
        return "";
      };
      case (?v) switch (v) {
        case (#Object(gasPriceFields)) {
          let gasPrice = await utils.getFieldAsString(gasPriceFields, "result");
          return gasPrice;
        };
        case _ {
          Debug.print("Unexpected JSON structure");
          return "";
        };
      };
    };
  };

  // TODO:

  //Check how to run this function periodically and save the status of the invoices, if they have been paid in Lightning network or not
  //If they have not been paid this function should call the alby_testnet.mo `payInvoice` with the corresponding invocieId

  public func readRSKSmartContractEvents() : async [Event] {

    let ic : Types.IC = actor ("aaaaa-aa");

    // Topic for encoded keccack-256 hash of SwapToLightningNetwork event
    let topics : [Text] = ["0x2fe70d4bbeafbc963084344fa9d6159351d9a2323787c90fba21fdc1909dc596"];

    let blockNumber : Text = "0x409492"; // We will filter after the contract creation

    // Prepare the JSON-RPC request payload
    let jsonRpcPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getLogs\", \"params\": [{ \"address\": \"" # contractAddress # "\", \"fromBlock\": \"" # blockNumber # "\", \"topics\": " # encodeTopics(topics) # " }] }";

    let decodedText = await utils.httpRequest(?jsonRpcPayload, rskNodeUrl, null, "post");

    // Use a helper function to handle the rest of the logic
    let events = await handleLogs(decodedText);

    // Return the decoded response body (or any other relevant information)
    return events;
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
    Debug.print("Input logText: " # logText); // Print the input logText to verify its structure

    var events : [Event] = [];

    let parsedJSON = JSON.parse(logText);

    switch (parsedJSON) {
      case (null) {
        Debug.print("JSON parsing failed");
      };
      case (?v) switch (v) {
        case (#Array(logArray)) {

          for (log in logArray.vals()) {
            Debug.print("Processing log: " # JSON.show(log)); // Print each log entry before parsing

            switch (log) {
              case (#Object(logFields)) {
                let finalAddress = await utils.getFieldAsString(logFields, "address");

                let data0x = await utils.getFieldAsString(logFields, "data");

                let data = utils.subText(data0x, 3, data0x.size() -1);

                Debug.print("data: " # data);

                let dataBytes = AU.fromText(data);
                Debug.print("dataBytes length: " # Nat.toText(Iter.size(Array.vals(dataBytes))));

                let amountBytes = AU.slice(dataBytes, 0, 32); // Changed start index to 0 and length to 32
                let invoiceIdBytes = AU.slice(dataBytes, 32, 32); // Changed start index to 32 and length to 32

                let amount = AU.toNat256(amountBytes);
                let invoiceIdHexString = AU.toText(invoiceIdBytes);

                Debug.print("hex invoice : " # invoiceIdHexString);

                let invoiceIdString = await utils.bytes32ToString(invoiceIdHexString);
                switch (invoiceIdString) {
                  case (null) {
                    Debug.print("invoiceId is null");
                  };
                  case (?invoiceIdString) {
                    Debug.print("amount: " # Nat.toText(amount));
                    Debug.print("invoiceId: " # invoiceIdString);
                  };
                };

                Debug.print("finalAddress: " # finalAddress);

                let newEvent : Event = {
                  address = switch (invoiceIdString) {
                    case (null) { "" }; // or some other default value
                    case (?validString) { validString };
                  };
                };
                events := Array.append(events, [newEvent]);

              };
              case _ { Debug.print("Unexpected JSON structure") };
            };
          };
        };
        case _ { Debug.print("Parsed JSON is not an array") };
      };
    };

    Debug.print("Finished processing logs.");
    return events;
  };
};
