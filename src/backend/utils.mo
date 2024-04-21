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
import Nat32 "mo:base/Nat32";
import Error "mo:base/Error";
import Result "mo:base/Result";

module {

    type JSONField = (Text, JSON.JSON);

    public func httpRequest(
        jsonRpcPayload : ?Text,
        url : Text,
        headers : ?[{ name : Text; value : Text }],
        method : Text,
        transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload,
    ) : async Text {
        let ic : Types.IC = actor ("aaaaa-aa");
        var retryCount : Nat = 0;
        let maxRetries : Nat = 6; // Changed to 6 retries
        var shouldRetry : Bool = true;

        let payloadAsNat8 : ?[Nat8] = switch (jsonRpcPayload) {
            case (null) { null };
            case (?payload) { ?Blob.toArray(Text.encodeUtf8(payload)) };
        };

        let defaultHeaders = [{
            name = "Content-Type";
            value = "application/json";
        }];

        let actualHeaders = switch (headers) {
            case (null) { defaultHeaders };
            case (?userHeaders) { userHeaders };
        };

        let httpMethod = switch (method) {
            case ("post") { #post };
            case ("get") { #get };
            case ("head") { #head };
            case _ { #post };
        };

        let transform_context : Types.TransformContext = {
            function = transform;
            context = Blob.fromArray([]);
        };

        let httpRequest : Types.HttpRequestArgs = {
            url = url;
            headers = actualHeaders;
            method = httpMethod;
            body = payloadAsNat8;
            max_response_bytes = null;
            transform = ?transform_context;
        };

        while (retryCount < maxRetries and shouldRetry) {
            try {
                Cycles.add(17_000_000_000 + (5_000_000_000 * retryCount)); // Added extra cycles based on the retry count

                let httpResponse : Types.HttpResponsePayload = await ic.http_request(httpRequest);

                let responseBody : Blob = Blob.fromArray(httpResponse.body);
                let decodedText : Text = switch (Text.decodeUtf8(responseBody)) {
                    case (null) "No value returned";
                    case (?y) y;
                };

                shouldRetry := false;
                return decodedText;
            } catch (e : Error.Error) {
                let errorMessage : Text = Error.message(e);
                if (Text.contains(errorMessage, #text "cycles are required")) {

                    retryCount += 1;
                } else {
                    shouldRetry := false;
                    return "Error: " # errorMessage;
                };
            };
        };

        return "Max retries reached. Unable to complete the request.";
    };

    public func getFieldAsString(fields : [JSONField], key : Text) : async Text {
        Debug.print("Searching for key: " # key);
        let field = Array.find(
            fields,
            func((k : Text, v : JSON.JSON)) : Bool {
                k == key;
            },
        );
        switch (field) {
            case (?(_, value)) {
                JSON.show(value);
            };
            case _ {
                "";
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
        let iter = Iter.toArray<Char>(Text.toIter(value));
        for (index in Iter.range(indexStart, indexEndValid - 1)) {
            result := result # Char.toText(iter[index]);
        };

        return result;
    };

    public func trim(value : Text) : Text {

        let iter = Iter.toArray<Char>(Text.toIter(value));
        var startIndex = 0;
        var endIndex = iter.size() - 1;

        // Check if the input is empty
        if (iter.size() == 0) {
            Debug.print("Input is empty. Returning empty string.");
            return "";
        };

        // Helper function to check if a character is non-printable
        let isNonPrintable = func(ch : Char) : Bool {
            let code = Char.toNat32(ch);
            return (code < 32) or (code >= 127 and code <= 159);
        };

        var result : Text = "";
        for (index in Iter.range(startIndex, endIndex)) {
            let currentChar = iter[index];
            if (Char.toText(currentChar) == "") {} else if (isNonPrintable(currentChar)) {} else {
                result := result # Char.toText(currentChar);
            };
        };

        return result;
    };

    public func hexStringToNat64(hexString : Text) : Nat64 {

        Debug.print("hexStringToNat64: "#hexString);
        let hexStringArray = Iter.toArray(Text.toIter(hexString));
        let noPrefixString = if (hexString.size() >= 3 and hexStringArray[1] == '0' and hexStringArray[2] == 'x') {
            subText(hexString, 3, hexString.size() - 1);
        } else {
            hexString;
        };
        Debug.print("noPrefixString "#noPrefixString);

        let cleanHexString = Text.trimEnd(noPrefixString, #text "\"");
        Debug.print("cleanHexString: " # cleanHexString);
        let treatedCleanHexString = Text.trimStart(cleanHexString, #char '0');
        Debug.print("treatedCleanHexString: " # Text.trimStart(treatedCleanHexString, #char 'x'));

        var result : Nat64 = 0;
        var power : Nat64 = 1;
        let charsArray = Iter.toArray(Text.trimStart(treatedCleanHexString, #char 'x').chars());
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
                case (_) {
                    Debug.print("Unexpected character in hex string: " # Text.fromChar(char));
                    0;
                };
            };
            result += Nat64.fromNat(digitValue) * power;
            power *= 16;
        };

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

    public func getValue(json : ?JSON.JSON, value : Text) : async Text {
        switch (json) {
            case (null) {
                return "";
            };
            case (?v) switch (v) {
                case (#Object(gasPriceFields)) {
                    let gasPrice = await getFieldAsString(gasPriceFields, value);
                    return gasPrice;
                };
                case _ {
                    return "";
                };
            };
        };
    };
    public func decodeTransferERC20Data(data : Text) : async Result.Result<(Text, Nat), Text> {
        Debug.print("Received data: " # data);
        if (Text.size(data) < 138) {
            Debug.print("Error: Data too short");
            return #err("Data too short");
        };

        // Correctly extract the address part
        // The address starts at position 10 (after '0xa9059cbb') and is 40 characters long, but with padding in the data string
        let addressHex = TU.right(TU.left(data, 74), 35); // Extract address with padding
        let address = "0x" # addressHex; // Prepend '0x'
        Debug.print("Extracted address: " # address);

        // Correctly extract the amount part
        let amountHex = TU.right(data, 75); // Last 64 characters for amount
        Debug.print("Amount hex: " # amountHex);
        let amount = hexStringToNat64(amountHex); // Convert hex string to Nat
        let amountNat = Nat64.toNat(amount);

        Debug.print("Converted amount: " # Nat.toText(amountNat));

        return #ok((address, amountNat));
    };

};
