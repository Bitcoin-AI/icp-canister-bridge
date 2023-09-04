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


import JSON "mo:json/JSON";
import Buffer "mo:base-0.7.3/Buffer";




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

public func handleLogs(decodedText: Text) : async [Event] {
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
              let finalAddress = getFieldAsString(logFields, "address");

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




private func getFieldAsString(fields: [JSONField], key: Text) : Text {
let field = Array.find(fields, func((k: Text, v: JSON.JSON)): Bool { k == key });
  switch (field) {
    case (?(_, #string(value))) { value };
    case _ { "Unknown" };
  };
};






  public func hexToNat(hex: Text) :  async Nat {
  var value : Nat = 0;
  let iter = Text.toIter(hex);
  var done = false;
  while (not done) {
    switch (iter.next()) {
      case null { done := true };
      case (?c) {
        let digitValue : Nat = switch (c) {
          case '0' { 0 };
          case '1' { 1 };
          case '2' { 2 };
          case '3' { 3 };
          case '4' { 4 };
          case '5' { 5 };
          case '6' { 6 };
          case '7' { 7 };
          case '8' { 8 };
          case '9' { 9 };
          case 'A' { 10 };
          case 'B' { 11 };
          case 'C' { 12 };
          case 'D' { 13 };
          case 'E' { 14 };
          case 'F' { 15 };
          case _ { 0 };
        };
        value := value * 16 + digitValue;
      };
    };
  };
  value
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