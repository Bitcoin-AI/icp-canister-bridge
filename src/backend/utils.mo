import Types "Types";
import Blob "mo:base-0.7.3/Blob";
import Cycles "mo:base-0.7.3/ExperimentalCycles";
import Text "mo:base-0.7.3/Text";
import JSON "mo:json/JSON";
import Array "mo:base-0.7.3/Array";
import Debug "mo:base-0.7.3/Debug";
import RLP "mo:rlp/hex/lib";
import Iter "mo:base-0.7.3/Iter";
import Nat8 "mo:base-0.7.3/Nat8";
import Char "mo:base-0.7.3/Char";
import Nat "mo:base-0.7.3/Nat";
import Nat64 "mo:base-0.7.3/Nat64";
import PublicKey "mo:libsecp256k1/PublicKey";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";
import HU "mo:evm-tx/utils/HashUtils";

module {

    type JSONField = (Text, JSON.JSON);

    public func httpRequest(jsonRpcPayload : ?Text, url : Text, headers : ?[{ name : Text; value : Text }], method : Text) : async Text {
        let ic : Types.IC = actor ("aaaaa-aa");

        let payloadAsNat8 : ?[Nat8] = switch (jsonRpcPayload) {
            case (null) { null };
            case (?payload) { ?Blob.toArray(Text.encodeUtf8(payload)) };
        };

        // Prepare the default headers
        let defaultHeaders = [{
            name = "Content-Type";
            value = "application/json";
        }];

        // Use the provided headers or the default headers if none are provided
        let actualHeaders = switch (headers) {
            case (null) { defaultHeaders };
            case (?userHeaders) { userHeaders };
        };

        // Determine the HTTP method to use
        let httpMethod = switch (method) {
            case ("post") { #post };
            case ("get") { #get };
            case ("head") { #head };
            case _ { #post }; // default to POST if an unrecognized method is passed
        };

        // Prepare the HTTP request
        let httpRequest : Types.HttpRequestArgs = {
            url = url;
            headers = actualHeaders;
            method = httpMethod;
            body = payloadAsNat8;
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

    public func getFieldAsString(fields : [JSONField], key : Text) : async Text {
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

    public func bytes32ToString(hexString : Text) : async ?Text {
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

    public func hexToNat(hex : Text) : async Nat {
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

    public func subText(value : Text, indexStart : Nat, indexEnd : Nat) : Text {

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
    public func hexStringToNat64(hexString : Text) : Nat64 {

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

    public func publicKeyToAddress(publicKey : [Nat8]) : Text {
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

    public func getValue(json : ?JSON.JSON, value: Text) : async Text {
        switch (json) {
            case (null) {
                Debug.print("JSON parsing failed");
                return "";
            };
            case (?v) switch (v) {
                case (#Object(gasPriceFields)) {
                    let gasPrice = await getFieldAsString(gasPriceFields, value);
                    return gasPrice;
                };
                case _ {
                    Debug.print("Unexpected JSON structure");
                    return "";
                };
            };
        };
    };

};
