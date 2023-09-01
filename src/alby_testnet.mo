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
import Hex "Hex";

// Actor
actor {
  // Declare IC management canister
  let ic: Types.IC = actor ("aaaaa-aa");

  // Set the base URL of your LND REST API: https://github.com/getAlby/lightning-browser-extension/wiki/Test-setup
  let lndBaseUrl: Text = "https://lnd1.regtest.getalby.com";
  let macaroon: Text = "0201036c6e6402f801030a10b3bf6906c1937139ac0684ac4417139d1201301a160a0761646472657373120472656164120577726974651a130a04696e666f120472656164120577726974651a170a08696e766f69636573120472656164120577726974651a210a086d616361726f6f6e120867656e6572617465120472656164120577726974651a160a076d657373616765120472656164120577726974651a170a086f6666636861696e120472656164120577726974651a160a076f6e636861696e120472656164120577726974651a140a057065657273120472656164120577726974651a180a067369676e6572120867656e657261746512047265616400000620a3f810170ad9340a63074b6dded31ed83a7140fd26c7758856111583b7725b2b";

  // This method sends a GET request to retrieve information from a Lightning node
  // https://lightning.engineering/api-docs/api/lnd/lightning/get-info
  public func getLightningInfo() : async Text {

    // Setup URL and request headers
    let url: Text = lndBaseUrl # "/v1/getinfo";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon}
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
  // https://lightning.engineering/api-docs/api/lnd/lightning/add-invoice/index.html
  public func generateInvoice(amount: Nat) : async Text {

    // Setup URL and request headers
    let url: Text = lndBaseUrl # "/v1/invoices";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon}
    ];

    let request_body_json: Text = "{ \"value\" : 100,\"memo\" : \"Test ICP\", \"is_amp\": true }";
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
    // Once payment is done, we trigger release of rbtc from rsk
  };
  // https://lightning.engineering/api-docs/api/lnd/lightning/send-payment
  public func payInvoice(invoice: Text) : async Text {

    // First we need to check if RSK transaction has been done in our contract. After that we will use that method to release the btc in lightning network

    // Setup URL and request headers
    let url: Text = lndBaseUrl # "/v1/channels/transaction-stream";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon}
    ];


    let request_body_json: Text = "{ \"payment_request\" : \"" # invoice # "\" }";
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
  // https://lightning.engineering/api-docs/api/lnd/lightning/lookup-invoice
  public func checkInvoice(payment_hash: Text) : async Text {

    // Setup URL and request headers
    let url: Text = lndBaseUrl # "/v1/invoice/" # payment_hash;
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon}
    ];
    Debug.print(url);
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
