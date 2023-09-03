// Existing imports
import Types "Types";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";





actor {

    type Event = {
        address: Text;
    };


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
  
  let logs = Text.split(decodedText, #text("\"result\":"));
  let _ = logs.next(); // Skip the first part
  let maybeLogText = logs.next(); // Get the second part
  
  switch (maybeLogText) {
    case (null) { 
      Debug.print("No logs found.");
      return []; 
    }; // Do nothing if no logs
    case (?logText) { 
      Debug.print("Processing logs: " # logText);
      return await processLog(logText); 
    };
  };
};



public func processLog(logText: Text) : async [Event] {
  var events: [Event] = [];
  let logArray = Text.split(logText, #text("},"));


  for (log in logArray) {
    Debug.print("Processing log: " # log);

    let maybeAddress = Text.split(log, #text("\"address\":\"")).next();
    let maybeData = Text.split(log, #text("\"data\":\"")).next();
    let maybeTimestamp = Text.split(log, #text("\"blockNumber\":\"")).next();

    switch (maybeAddress, maybeData, maybeTimestamp) {
      case (?address, ?data, ?timestamp) {
        let finalAddress = switch (Text.split(address, #text("\"")).next()) { case null { "Unknown" }; case (?a) { a } };
        let finalData = switch (Text.split(data, #text("\"")).next()) { case null { "Unknown" }; case (?d) { d } };
        let finalTimestamp = switch (Text.split(timestamp, #text("\"")).next()) { case null { "Unknown" }; case (?t) { t } };

        // Extract amount and invoiceId from 'data' field
        let amountHex = switch (Text.split(finalData, #text("000000000000000000000000000000000000000000000000")).next()) { case null { "0" }; case (?a) { a } };
        let invoiceIdHex = switch (Text.split(finalData, #text("000000000000000000000000000000000000000000000000")).next()) { case null { "Unknown" }; case (?i) { i } };
        let amount = await hexToNat(amountHex); // Now you can use await here

      //  let invoiceIdBlob = Blob.fromArray(Blob.toArray(Blob.fromHex(invoiceIdHex)).unwrap());
      //   let invoiceId = switch (Text.decodeUtf8(invoiceIdBlob)) {
      //     case (null) "Unknown";
      //     case (?text) text;
      //   };

        Debug.print("finalAddress" # finalAddress);


        events := Array.append<Event>(events, [ { address = finalAddress } ]);
      };
      case _ { /* Handle error or skip */ };
    };
  };
  Debug.print("Finished processing logs.");

  events; // This should work now
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