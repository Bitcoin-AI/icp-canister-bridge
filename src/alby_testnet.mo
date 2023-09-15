import Debug "mo:base-0.7.3/Debug";
import Blob "mo:base-0.7.3/Blob";
import Cycles "mo:base-0.7.3/ExperimentalCycles";
import Error "mo:base-0.7.3/Error";
import Array "mo:base-0.7.3/Array";
import Nat8 "mo:base-0.7.3/Nat8";
import Nat64 "mo:base-0.7.3/Nat64";
import Text "mo:base-0.7.3/Text";
import Nat "mo:base-0.7.3/Nat";
import Iter "mo:base-0.7.3/Iter";
import Char "mo:base-0.7.3/Char";

import PublicKey "mo:libsecp256k1/PublicKey";
import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";
import HU "mo:evm-tx/utils/HashUtils";

import Legacy "mo:evm-tx/transactions/Legacy";
import Transaction "mo:evm-tx/Transaction";

import JSON "mo:json/JSON";
import RLP "mo:rlp/hex/lib";
import Context "mo:evm-tx/Context";

// Import the custom types we have in Types.mo
import Types "Types";

// Actor
actor {
  // Declare IC management canister
  let ic: Types.IC = actor ("aaaaa-aa");
  type JSONField = (Text, JSON.JSON);
  let contractAddress : Text = "0x953CD84Bb669b42FBEc83AD3227907023B5Fc4FF";

  // Set the base URL of your LND REST API: https://github.com/getAlby/lightning-browser-extension/wiki/Test-setup
  let lndBaseUrl: Text = "https://lnd1.regtest.getalby.com";
  let serviceRest: Text = "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/";
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
    let keyName = "dfx_test_key";
    let derivationPath = [Blob.fromArray([0x00, 0x00]), Blob.fromArray([0x00, 0x01])]; // Example derivation path
    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));
    let messageHash = AU.toText(HU.keccak(TU.encodeUtf8(invoice), 256));
    Debug.print(messageHash);
    let signature = await* IcEcdsaApi.sign(keyName, derivationPath, Text.encodeUtf8(messageHash));
    // Building transactionData

    // Setup URL and request headers
    let url: Text = serviceRest;
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "signature"; value = Nat.toText(Blob.toArray(signature).size()) }
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

  public func getEvmAddr(): async Text {
    let keyName = "dfx_test_key";
    let derivationPath = [Blob.fromArray([0x00, 0x00]), Blob.fromArray([0x00, 0x01])]; // Example derivation path
    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let address = publicKeyToAddress(publicKey); // Remove '0x' prefix
    return address;
  };

  private func publicKeyToAddress(publicKey : [Nat8]) : Text {
    let p = switch (PublicKey.parse_compressed(publicKey)) {
      case (#err(e)) {
        return "";
      };
      case (#ok(p)) {
        let keccak256_hex = AU.toText(HU.keccak(AU.right(p.serialize(), 1), 256));
        let address : Text = TU.right(keccak256_hex, 24);

        return address;
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
  private func hexStringToNat64(hexString : Text) : Nat64 {

    Debug.print("Input hexString: " # hexString);

    Debug.print("Size  hexString: " # Nat.toText(hexString.size()));

    let hexStringArray = Iter.toArray(Text.toIter(hexString));
    let cleanHexString = if (hexString.size() >= 2 and hexStringArray[1] == '0' and hexStringArray[2] == 'x') {
      subText(hexString, 3, hexString.size() -1);
    } else {
      hexString;
    };

    Debug.print("Clean hexString: " # cleanHexString);

    var result : Nat64 = 0;
    var power : Nat64 = 1;

    let charsArray = Iter.toArray(cleanHexString.chars());
    let arraySize = charsArray.size();

    for (i in Iter.range(0, arraySize - 1)) {
      let char = charsArray[arraySize - i - 1];
      let digitValue = switch (char) {
        case ('0') { 0 };
        case ('1') { 1 };
        case ('2') { 2 };
        case ('3') { 3 };
        case ('4') { 4 };
        case ('5') { 5 };
        case ('6') { 6 };
        case ('7') { 7 };
        case ('8') { 8 };
        case ('9') { 9 };
        case ('a') { 10 };
        case ('b') { 11 };
        case ('c') { 12 };
        case ('d') { 13 };
        case ('e') { 14 };
        case ('f') { 15 };
        case (_) { 0 }; // Default case, you might want to handle this differently
      };
      result += Nat64.fromNat(digitValue) * power;
      power *= 16;
    };

    Debug.print("Result: " # Nat64.toText(result));

    result;
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
