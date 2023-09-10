// Existing imports
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

import JSON "mo:json/JSON";
import Buffer "mo:base-0.7.3/Buffer";

import Helper "mo:evm-tx/transactions/Helper";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";

import HU "mo:evm-tx/utils/HashUtils";
import Context "mo:evm-tx/Context";

import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";

import RLP "mo:rlp/hex/lib";

actor {

  //Create the ECDSA pair here for this canister

  // let keyName = "rsk_key";
  //  Derivaton path : m / purpose' / coin_type' / account' / change / address_index

  // let derivationPath = [Blob.fromArray([0x44, 0x89, 0x00, 0x00, 0x00]), Blob.fromArray([0x89, 0x00, 0x00, 0x00, 0x00]), Blob.fromArray([0x00, 0x00, 0x00, 0x00]), Blob.fromArray([0x00, 0x00, 0x00, 0x00]), Blob.fromArray([0x00, 0x00, 0x00, 0x00])];
  // let publicKey : async Blob = IcEcdsaApi.create(keyName, derivationPath);

  type Event = {
    address : Text;
  };

  type JSONField = (Text, JSON.JSON);

  let rskNodeUrl : Text = "https://rsk.getblock.io/437f13d7-2175-4d2c-a8c4-5e45ef6f7162/testnet/";

  let contractAddress : Text = "0x953CD84Bb669b42FBEc83AD3227907023B5Fc4FF";

  // Sign transactions

  //   public func signTransaction(messageHash: Blob) : async Blob {
  //     if (Principal.caller() != Principal.fromActor(this)) {
  //         throw "Unauthorized caller";
  //     };
  //     let signature : async Blob = IcEcdsaApi.sign(keyName, derivationPath, messageHash);
  //     return await signature;
  // };

  public func swapToLightningNetwork() : async Text {

    let address = "01110101";

    // Building transactionData

    let method_sig = "transfer(address,uint256)";
    let keccak256_hex = AU.toText(HU.keccak(TU.encodeUtf8(method_sig), 256));
    let method_id = TU.left(keccak256_hex, 7);

    let address_64 = TU.fill(TU.right(address, 2), '0', 64);

    let amount_hex = AU.toText(AU.fromNat256(1000));
    let amount_256 = TU.fill(amount_hex, '0', 256);

    let data = "0x" #method_id # address_64 # amount_256;

    //Getting gas Price
    let gasPricePayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_gasPrice\", \"params\": [] }";
    let responseGasPrice : Text = await httpRequest(gasPricePayload);
    let parsedGasPrice = JSON.parse(responseGasPrice);
    let gasPrice = await getValue(parsedGasPrice);

    Debug.print("gasPrice" # gasPrice);

    //Estimating gas
    let estimateGasPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_estimateGas\", \"params\": [{ \"to\": \"" # contractAddress # "\", \"value\": \"" # amount_256 # "\", \"data\": \"" # data # "\" }] }";
    let responseGas : Text = await httpRequest(estimateGasPayload);
    let parsedGasValue = JSON.parse(responseGas);
    let gas = await getValue(parsedGasValue);

    Debug.print("gas" # gas);

    //Getting nonce

    let noncePayLoad : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionCount\", \"params\": [\"" # address # "\", \"latest\"] }";
    let responseNoncepayLoad : Text = await httpRequest(noncePayLoad);

    Debug.print("nonceResponse" # responseNoncepayLoad);

    let parsedNonce = JSON.parse(responseNoncepayLoad);
    let nonce = await getValue(parsedNonce);

    Debug.print("nonce" # nonce);

    // Transaction details
    let transaction = {
      nonce = nonce; // nonce obtained from your existing code
      gasPrice = gasPrice; // gasPrice obtained from your existing code
      gasLimit = gas; // gas obtained from your existing code
      to = contractAddress; // replace with your contract address
      value = amount_256; // replace with the actual value
      data = data;
      chainId = 1; // replace with the actual chain ID
      v = 0;
      r = 0;
      s = 0;
    };

    // Step 3.2: Hash the RLP encoded transaction using Keccak256
    let transaction_encoded = RLP.encode(transaction);

    //   // Step 3.3: Sign the hash using the private key with ECDSA
    //   let signature = ECDSA.signWithPrivateKey(transaction_hash, privateKey);

    //   // Step 3.4: RLP encode the signed transaction
    //   let signed_transaction = RLP.encode({
    //     nonce = transaction.nonce,
    //     gasPrice = transaction.gasPrice,
    //     gasLimit = transaction.gasLimit,
    //     to = transaction.to,
    //     value = transaction.value,
    //     data = transaction.data,
    //     chainId = transaction.chainId,
    //     v = signature.v,
    //     r = signature.r,
    //     s = signature.s
    //   });

    //   // Step 3.5: Convert the signed transaction to a hex string
    //   let signed_transaction_hex = toHex(signed_transaction);

    //   return signed_transaction_hex;

    return "";
  };

  private func signWithPrivateKey(transaction_hash : Blob, privateKeyText : Text) : async ?Text {
    let context = Context.allocECMultContext(null);
    let privateKeyBlob = Blob.fromText(privateKeyText);
    let privateKeyArray = Blob.toArray(privateKeyBlob);

    switch (SecretKey.parse(privateKeyArray)) {
      case (#err(msg)) {
        return null;
      };
      case (#ok(privateKey)) {
        let message_parsed = Message.parse(Blob.toArray(transaction_hash));
        switch (Ecdsa.sign_with_context(message_parsed, privateKey, context, null)) {
          case (#err(msg)) {
            return null;
          };
          case (#ok(signature)) {
            return ?signature;
          };
        };
      };
    };
  };

  private func httpRequest(jsonRpcPayload : Text) : async Text {

    let ic : Types.IC = actor ("aaaaa-aa");

    let payloadAsBlob : Blob = Text.encodeUtf8(jsonRpcPayload);
    let payloadAsNat8 : [Nat8] = Blob.toArray(payloadAsBlob);

    // Prepare the HTTP request
    let httpRequest : Types.HttpRequestArgs = {
      url = rskNodeUrl;
      headers = [{ name = "Content-Type"; value = "application/json" }];
      method = #post;
      body = ?payloadAsNat8;
      max_response_bytes = null;
      transform = null;
    };

    // Add cycles to pay for the HTTP request
    Cycles.add(17_000_000_000);

    // Make the HTTP request and wait for the response
    let httpResponse : Types.HttpResponsePayload = await ic.http_request(httpRequest);

    // Decode the response body into readable text
    let responseBody : Blob = Blob.fromArray(httpResponse.body);
    let decodedText : Text = switch (Text.decodeUtf8(responseBody)) {
      case (null) "No value returned";
      case (?y) y;
    };

    return decodedText;

  };

  private func getValue(parsedGasPrice : ?JSON.JSON) : async Text {
    switch (parsedGasPrice) {
      case (null) {
        Debug.print("JSON parsing failed");
        return "";
      };
      case (?v) switch (v) {
        case (#Object(gasPriceFields)) {
          let gasPrice = await getFieldAsString(gasPriceFields, "result");
          return gasPrice;
        };
        case _ {
          Debug.print("Unexpected JSON structure");
          return "";
        };
      };
    };

  };
  public func readRSKSmartContractEvents() : async [Event] {

    let ic : Types.IC = actor ("aaaaa-aa");

    // RSK Testnet Node URL and Contract Address

    // Topic for encoded keccack-256 hash of SwapToLightningNetwork event
    let topics : [Text] = ["0x2fe70d4bbeafbc963084344fa9d6159351d9a2323787c90fba21fdc1909dc596"];

    let blockNumber : Text = "0x409492"; // Hexadecimal representation of 4,244,146

    // Prepare the JSON-RPC request payload
    let jsonRpcPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getLogs\", \"params\": [{ \"address\": \"" # contractAddress # "\", \"fromBlock\": \"" # blockNumber # "\", \"topics\": " # encodeTopics(topics) # " }] }";

    let payloadAsBlob : Blob = Text.encodeUtf8(jsonRpcPayload);
    let payloadAsNat8 : [Nat8] = Blob.toArray(payloadAsBlob);

    // Prepare the HTTP request
    let httpRequest : Types.HttpRequestArgs = {
      url = rskNodeUrl;
      headers = [{ name = "Content-Type"; value = "application/json" }];
      method = #post;
      body = ?payloadAsNat8;
      max_response_bytes = null;
      transform = null;
    };

    // Add cycles to pay for the HTTP request
    Cycles.add(17_000_000_000);

    // Make the HTTP request and wait for the response
    let httpResponse : Types.HttpResponsePayload = await ic.http_request(httpRequest);

    // Decode the response body into readable text
    let responseBody : Blob = Blob.fromArray(httpResponse.body);
    let decodedText : Text = switch (Text.decodeUtf8(responseBody)) {
      case (null) "No value returned";
      case (?y) y;
    };

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
                let finalAddress = await getFieldAsString(logFields, "address");

                let data0x = await getFieldAsString(logFields, "data");

                let data = subText(data0x, 3, data0x.size() -1);

                Debug.print("data: " # data);

                let dataBytes = AU.fromText(data);
                Debug.print("dataBytes length: " # Nat.toText(Iter.size(Array.vals(dataBytes))));

                let amountBytes = AU.slice(dataBytes, 0, 32); // Changed start index to 0 and length to 32
                let invoiceIdBytes = AU.slice(dataBytes, 32, 32); // Changed start index to 32 and length to 32

                let amount = AU.toNat256(amountBytes);
                let invoiceIdHexString = AU.toText(invoiceIdBytes);

                Debug.print("hex invoice : " # invoiceIdHexString);

                let invoiceIdString = await bytes32ToString(invoiceIdHexString);
                switch (invoiceIdString) {
                  case (null) {
                    Debug.print("invoiceId is null");
                  };
                  case (?invoiceIdString) {
                    Debug.print("amount: " # Nat.toText(amount));
                    Debug.print("invoiceId: " # invoiceIdString);
                  };
                };

                // Check if event/invoice is paid
                // if it is not paid then pay it ?   ---> Connection to lightning netwrk node alby_testnet.mo payInvoice send as input the macaroon string

                // call function
                //
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

  private func getFieldAsString(fields : [JSONField], key : Text) : async Text {
    Debug.print("Searching for key: " # key);
    let field = Array.find(
      fields,
      func((k : Text, v : JSON.JSON)) : Bool {
        Debug.print("Checking key: " # k);
        k == key;
      },
    );
    switch (field) {
      case (?(_, value)) {
        Debug.print("Found value: " # JSON.show(value));
        JSON.show(value);
      };
      case _ {
        Debug.print("Field not found");
        "Unknown";
      };
    };
  };

  private func bytes32ToString(hexString : Text) : async ?Text {
    Debug.print("Entering bytes32ToString function");

    switch (RLP.decode(hexString)) {
      case (#ok bytes) {
        let bytes32Value : Blob = Blob.fromArray(bytes);
        return Text.decodeUtf8(bytes32Value);
      };
      case (#err err) {
        Debug.print("Hex decoding error: " # err);
        return null;
      };
    };
  };

  private func hexToNat(hex : Text) : async Nat {
    let result = RLP.decode(hex);
    switch (result) {
      case (#ok bytes) {
        var value : Nat = 0;
        let length = bytes.size();
        for (i in Iter.range(0, length - 1)) {
          let byte = bytes[i];
          value := value * 16 + Nat8.toNat(byte);
        };
        return value;
      };
      case (#err err) {
        // handle error case here, for simplicity returning 0
        return 0;
      };
    };
  };

  private func subText(value : Text, indexStart : Nat, indexEnd : Nat) : Text {

    if (indexStart == 0 and indexEnd >= value.size()) {
      return value;
    } else if (indexStart >= value.size()) {
      return "";
    };

    var indexEndValid = indexEnd;
    if (indexEnd > value.size()) {
      indexEndValid := value.size();
    };

    var result : Text = "";
    var iter = Iter.toArray<Char>(Text.toIter(value));
    for (index in Iter.range(indexStart, indexEndValid - 1)) {
      result := result # Char.toText(iter[index]);
    };

    return result;
  };

};
