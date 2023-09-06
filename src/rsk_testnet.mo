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
import RLP "mo:rlp/hex/lib";





actor {

    type Event = {
        address: Text;
    };

    type JSONField = (Text, JSON.JSON);






    public func readRSKSmartContractEvents() :  async [Event] {


  
          let ic: Types.IC = actor ("aaaaa-aa");

        // RSK Testnet Node URL and Contract Address
        
        let rskNodeUrl: Text = "https://rsk.getblock.io/437f13d7-2175-4d2c-a8c4-5e45ef6f7162/testnet/";
        let contractAddress: Text = "0x953CD84Bb669b42FBEc83AD3227907023B5Fc4FF";

        // Topic for encoded keccack-256 hash of SwapToLightningNetwork event 
        let topics: [Text] = ["0x2fe70d4bbeafbc963084344fa9d6159351d9a2323787c90fba21fdc1909dc596"];

        let blockNumber: Text = "0x409492"; // Hexadecimal representation of 4,244,146

        // Prepare the JSON-RPC request payload
        let jsonRpcPayload: Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getLogs\", \"params\": [{ \"address\": \"" # contractAddress # "\", \"fromBlock\": \"" # blockNumber # "\", \"topics\": " # encodeTopics(topics) # " }] }";

        let payloadAsBlob: Blob = Text.encodeUtf8(jsonRpcPayload);
        let payloadAsNat8: [Nat8] = Blob.toArray(payloadAsBlob);

        // Prepare the HTTP request
        let httpRequest: Types.HttpRequestArgs = {
            url = rskNodeUrl;
            headers = [ { name = "Content-Type"; value = "application/json" } ];
            method = #post;
            body = ?payloadAsNat8;
            max_response_bytes = null;
            transform = null;
        };

        // Add cycles to pay for the HTTP request
        Cycles.add(17_000_000_000);

        // Make the HTTP request and wait for the response
        let httpResponse: Types.HttpResponsePayload = await ic.http_request(httpRequest);

        // Decode the response body into readable text
        let responseBody: Blob = Blob.fromArray(httpResponse.body);
        let decodedText: Text = switch (Text.decodeUtf8(responseBody)) {
            case (null) "No value returned";
            case (?y) y;
        };

        // Use a helper function to handle the rest of the logic
        let events = await handleLogs(decodedText);   

        // Return the decoded response body (or any other relevant information)
        return events;
    };




  private func encodeTopics(topics: [Text]) : Text {
      let joinedTopics = Array.foldLeft<Text, Text>(topics, "", func (acc, topic) {
          if (acc == "") {
              "\"" # topic # "\""
          } else {
              acc # "," # "\"" # topic # "\""
          }
      });
      return "[" # joinedTopics # "]";
  };

private func handleLogs(decodedText: Text) : async [Event] {
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


public func processLog(logText: Text) : async [Event] {
  Debug.print("Input logText: " # logText); // Print the input logText to verify its structure

  var events: [Event] = [];
    
  let parsedJSON = JSON.parse(logText);

  switch (parsedJSON) {
    case (null) {
      Debug.print("JSON parsing failed");
    };
    case (? v) switch (v) {
      case (#Array(logArray)) {

        for (log in logArray.vals()) {
          Debug.print("Processing log: " # JSON.show(log)); // Print each log entry before parsing

          switch (log) {
            case (#Object(logFields)) {
              let finalAddress = await getFieldAsString(logFields, "address");



            let data = "000000000000000000000000000000000000000000000000002386f26fc100003132330000000000000000000000000000000000000000000000000000000000";
             let dataBytes = AU.fromText(data);
            Debug.print("dataBytes length: " # Nat.toText(Iter.size(Array.vals(dataBytes))));

              
let amountBytes = AU.slice(dataBytes, 0, 32); // Changed start index to 0 and length to 32
let invoiceIdBytes = AU.slice(dataBytes, 32, 32); // Changed start index to 32 and length to 32


              let amount = AU.toNat256(amountBytes);
              let invoiceId = AU.toText(invoiceIdBytes);


              Debug.print("hex invoice : " # invoiceId);




            let test = await bytes32ToString(invoiceId);
            switch (test) {
              case (null) {
                Debug.print("invoiceId is null");
              };
              case (?validTest) {
                Debug.print("amount: " # Nat.toText(amount));
                Debug.print("invoiceId: " # validTest);
              };
};






              // Extract amount and invoiceId from 'data' field
              // ... (continue with your existing code to extract amount and invoiceId)

              Debug.print("finalAddress: " # finalAddress);

              events := Array.append(events, [{ address = finalAddress }]);
            };
            case _ { Debug.print("Unexpected JSON structure"); };
          };
        };
      };
      case _ { Debug.print("Parsed JSON is not an array"); };
    };
  };

  Debug.print("Finished processing logs.");
  return events;
};


private func getFieldAsString(fields: [JSONField], key: Text) : async Text {
  Debug.print("Searching for key: " # key);
  let field = Array.find(fields, func((k: Text, v: JSON.JSON)): Bool { 
    Debug.print("Checking key: " # k);
    k == key 
  });
  switch (field) {
    case (?(_, value)) { 
      Debug.print("Found value: " # JSON.show(value));
      JSON.show(value);
    };
    case _ { 
      Debug.print("Field not found");
      "Unknown" 
    };
  };
};




public func bytes32ToString(hexString: Text) : async ?Text {
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





public func hexToNat(hex: Text) : async Nat {
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

private func subText(value : Text, indexStart : Nat, indexEnd : Nat) :  Text {
    Debug.print("Entering subText function");
    Debug.print("Value: " # value);
    Debug.print("IndexStart: " # Nat.toText(indexStart));
    Debug.print("IndexEnd: " # Nat.toText(indexEnd));

    if (indexStart == 0 and indexEnd >= value.size()) {
        Debug.print("Returning entire value");
        return value;
    }
    else if (indexStart >= value.size()) {
        Debug.print("IndexStart is greater than or equal to value size, returning empty string");
        return "";
    };
    
    var indexEndValid = indexEnd;
    if (indexEnd > value.size()) {
        Debug.print("Adjusting indexEndValid to value size");
        indexEndValid := value.size();
    };

    Debug.print("IndexEndValid: " # Nat.toText(indexEndValid));

    var result : Text = "";
    var iter = Iter.toArray<Char>(Text.toIter(value));
    for (index in Iter.range(indexStart, indexEndValid - 1)) {
        Debug.print("Appending character at index: " # Nat.toText(index));
        result := result # Char.toText(iter[index]);
    };

    Debug.print("Result: " # result);

    return result;
};







    // private func parseJson(json: Text) : [YourLogType] {
    //     // Implement your JSON parsing logic here
    //     // ...
    //     return []; // Placeholder
    // };

    // private func isInvoicePaid(invoiceId: Text) : Bool {
    //     // Implement your logic to check if the invoice has been paid
    //     // ...
    //     return false; // Placeholder
    // };

    // private func payInvoice(invoiceId: Text, amount: Nat) : Bool {
    //     // Implement your logic to pay the invoice
    //     // ...
    //     return true; // Placeholder
    // };

    // private func markInvoiceAsPaid(invoiceId: Text) {
    //     // Implement your logic to mark the invoice as paid
    //     // ...
    // };

};