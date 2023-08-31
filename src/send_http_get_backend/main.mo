import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

// Import the custom types we have in Types.mo
import Types "Types";

// Actor
actor {
  // Declare IC management canister
  let ic: Types.IC = actor ("aaaaa-aa");
  // Disable TLS certificate verification
  // Set the base URL of your LND REST API => Need to fix TLS self signed certificates
  let lndBaseUrl: Text = "https://localhost:8084";

  // This method sends a GET request to retrieve information from a Lightning node
  public func getLightningInfo() : async Text {

    // Setup URL and request headers
    let url: Text = lndBaseUrl # "/v1/getinfo";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" }
    ];

    // Prepare the HTTP request
    let httpRequest: Types.HttpRequestArgs = {
      url = url;
      headers = requestHeaders;
      method = #get;
      body = null;
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
      case (null) { "No value returned" };
      case (?y) { y };
    };

    // Return the decoded response body
    decodedText
  };
};
