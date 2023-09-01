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
actor {

    public func readRSKSmartContractEvents() : async Text {


          let ic: Types.IC = actor ("aaaaa-aa");

        // RSK Testnet Node URL and Contract Address
        
        let rskNodeUrl: Text = "https://public-node.testnet.rsk.co/";
        let contractAddress: Text = "0x953CD84Bb669b42FBEc83AD3227907023B5Fc4FF";

        // Topic for encoded keccack-256 hash of SwapToLightningNetwork event 
        let topics: [Text] = ["0x2fe70d4bbeafbc963084344fa9d6159351d9a2323787c90fba21fdc1909dc596"];

        // Prepare the JSON-RPC request payload
        let jsonRpcPayload: Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getLogs\", \"params\": [{ \"address\": \"" # contractAddress # "\", \"topics\": " # encodeTopics(topics) # " }] }";
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
        // handleLogs(decodedText);

        // Return the decoded response body (or any other relevant information)
        return decodedText;
    };

    // private func handleLogs(decodedText: Text) {
    //     // Parse the JSON response to read the logs
    //     let logs = parseJson(decodedText); // Assume parseJson is a function that parses the JSON string into a structured format

    //     // Loop through each log entry to check if the invoice has been paid
    //     for (log in logs) {
    //         let invoiceId = log.topics[1]; // Assuming the invoiceId is the second topic in the log
    //         let amount = log.data; // Assuming the amount is in the data field of the log

    //         // Check if this invoice has been paid (You'll need to implement this function)
    //         if (not isInvoicePaid(invoiceId)) {
    //             // If the invoice has not been paid, proceed to pay it (You'll need to implement this function)
    //             let paymentResult = payInvoice(invoiceId, amount);
    //             if (paymentResult) {
    //                 // Mark the invoice as paid (You'll need to implement this function)
    //                 markInvoiceAsPaid(invoiceId);
    //             }
    //         }
    //     }
    // };

    private func encodeTopics(topics: [Text]) : Text {
        let joinedTopics = Array.foldLeft<Text, Text>(topics, "", func (acc, topic) {
            if (acc == "") {
                "\"" # topic # "\""
            } else {
                acc # "," # "\"" # topic # "\""
            }
        });
        return "[" # joinedTopics # "]";
    }


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