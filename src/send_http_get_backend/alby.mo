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

  // Set the base URL of your LND REST API
  let lndBaseUrl: Text = "https://localhost:8084";
  let albyBaseUrl: Text = "https://api.getalby.com";
  let accessToken = "TEST";
  // This method sends a GET request to retrieve information from a Lightning node
  public func getLightningInfo() : async Text {

    // Setup URL and request headers
    let url: Text = albyBaseUrl # "/balance";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Authorization"; value = "Bearer " # accessToken}
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
  public func generateInvoice(amount: Nat) : async Text {

    // Setup URL and request headers
    let url: Text = albyBaseUrl # "/invoices";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Authorization"; value = "Bearer " # accessToken}
    ];

    let request_body_json: Text = "{ \"amount\" : 100,\"description\" : \"Test ICP\" }";
    let request_body_as_Blob: Blob = Text.encodeUtf8(request_body_json);
    let request_body_as_nat8: [Nat8] = Blob.toArray(request_body_as_Blob); // e.g [34, 34,12, 0]

    // Prepare the HTTP request
    let httpRequest: Types.HttpRequestArgs = {
      url = url;
      headers = requestHeaders;
      method = #post;
      body = ?request_body_as_nat8;
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
  public func checkInvoice(payment_hash: Text) : async Text {

    // Setup URL and request headers
    let url: Text = albyBaseUrl # "/invoices/" # payment_hash;
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Authorization"; value = "Bearer " # accessToken}
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
