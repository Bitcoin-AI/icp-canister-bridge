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
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";

import PublicKey "mo:libsecp256k1/PublicKey";

import Signature "mo:libsecp256k1/Signature";

import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";
import HU "mo:evm-tx/utils/HashUtils";

import Legacy "mo:evm-tx/transactions/Legacy";
import Transaction "mo:evm-tx/Transaction";

import JSON "mo:json/JSON";
import RLP "mo:rlp/hex/lib";
import Context "mo:evm-tx/Context";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

import Rlp "mo:rlp";

import RlpUtils "mo:evm-tx/utils/RlpUtils";

import RlpTypes "mo:rlp/types";

// Import the custom types we have in Types.mo
import Types "Types";
import utils "utils";

// Module
module {
  // Declare IC management canister
  type JSONField = (Text, JSON.JSON);
  let contractAddress : Text = "0x953CD84Bb669b42FBEc83AD3227907023B5Fc4FF";

  // Set the base URL of your LND REST API: https://github.com/getAlby/lightning-browser-extension/wiki/Test-setup
  let lndBaseUrl : Text = "https://lnd1.regtest.getalby.com";
  let serviceRest : Text = "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/";
  // Ideally the macaroon would give only access to read invoices states and specific for the service
  let macaroon : Text = "0201036c6e6402f801030a10b3bf6906c1937139ac0684ac4417139d1201301a160a0761646472657373120472656164120577726974651a130a04696e666f120472656164120577726974651a170a08696e766f69636573120472656164120577726974651a210a086d616361726f6f6e120867656e6572617465120472656164120577726974651a160a076d657373616765120472656164120577726974651a170a086f6666636861696e120472656164120577726974651a160a076f6e636861696e120472656164120577726974651a140a057065657273120472656164120577726974651a180a067369676e6572120867656e657261746512047265616400000620a3f810170ad9340a63074b6dded31ed83a7140fd26c7758856111583b7725b2b";

  // This method sends a GET request to retrieve information from a Lightning node
  // https://lightning.engineering/api-docs/api/lnd/lightning/get-info
  public func getLightningInfo() : async Text {

    // Setup URL and request headers
    let url : Text = lndBaseUrl # "/v1/getinfo";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon },
    ];

    let decodedText : Text = await utils.httpRequest(null, url, ?requestHeaders, "get");
    // Return the decoded response body
    decodedText;
  };
  // https://lightning.engineering/api-docs/api/lnd/lightning/add-invoice/index.html
  public func generateInvoice(amount : Nat, evm_addr : Text) : async Text {

    // Setup URL and request headers
    let url : Text = lndBaseUrl # "/v1/invoices";
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon },
    ];

    let request_body_json : Text = "{ \"value\" : \"" # Nat.toText(amount) # "\",\"memo\" : \"" # evm_addr # "\"  }";
    let decodedText : Text = await utils.httpRequest(?request_body_json, url, ?requestHeaders, "post");

    // Return the decoded response body
    decodedText
    // Once payment is done, we trigger release of rbtc from rsk
  };
  // https://lightning.engineering/api-docs/api/lnd/lightning/send-payment
  // This function will only be callable by the rsk_testnet_mo function `readRSKSmartContractEvents` that  will decide
  // which invoices SHOULD  be paid (by calling this function with the corresponding invoiceId)
  // Check how to do access control e.g. This canister function will be only called by the rsk canister other function
  // Right now it will be maintained as public for testing.
  public func payInvoice(invoice : Text, derivationPath : [Blob], keyName : Text) : async Text {

    // First we need to check if RSK transaction has been done in our contract. After that we will use that method to release the btc in lightning network
    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let address = utils.publicKeyToAddress(publicKey); // Remove '0x' prefix

    if (address == "") {
      Debug.print("Could not get address!");
      return "";
    } else {
      Debug.print("Address: 0x" # address);
    };

    let ecCtx = Context.allocECMultContext(null);
    let keccak256_hex = HU.keccak(TU.encodeUtf8(invoice), 256);
    let message = AU.toText(HU.keccak(TU.encodeUtf8(invoice), 256));

    Debug.print("Message: " # message);

    let signatureBlob = Blob.toArray(await* IcEcdsaApi.sign(keyName, derivationPath, Blob.fromArray(keccak256_hex)));

    let signature = Signature.parse_standard(signatureBlob);

    switch (signature) {
      case (#err(msg)) {
        return "";
      };
      case (#ok(signature)) {
        let serializedSignature = signature.serialize();

        Debug.print("signature:" #AU.toText(serializedSignature));

        let request_icp_bridge_macaroon : Text = "{ \"payment_request\" : \"" # invoice # "\" }";

        let requestHeaders = [
          { name = "Content-Type"; value = "application/json" },
          { name = "Accept"; value = "application/json" },
          { name = "signature"; value = AU.toText(serializedSignature) },
        ];

        let response_icp_bridge_macaroon = await utils.httpRequest(?request_icp_bridge_macaroon, serviceRest, ?requestHeaders, "post");
        return response_icp_bridge_macaroon;
      };
    };

  };

  // https://lightning.engineering/api-docs/api/lnd/lightning/lookup-invoice
  public func checkInvoice(payment_hash : Text) : async Text {

    // Setup URL and request headers
    let url : Text = lndBaseUrl # "/v2/invoices/lookup?payment_hash=" # payment_hash;
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon },
    ];
    Debug.print(url);

    let responseText : Text = await utils.httpRequest(null, url, ?requestHeaders, "get");
    Debug.print(responseText);
    // Return the decoded response body
    return responseText;

  };

  // https://lightning.engineering/api-docs/api/lnd/router/track-payment-v2
  public func decodePayReq(payment_request : Text) : async Text {

    // Setup URL and request headers
    let url : Text = lndBaseUrl # "/v1/payreq/" # payment_request;
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "Grpc-Metadata-macaroon"; value = macaroon },
    ];
    Debug.print(url);

    let responseText : Text = await utils.httpRequest(null, url, ?requestHeaders, "get");
    Debug.print(responseText);
    // Return the decoded response body
    return responseText;

  };

  public func getEvmAddr(derivationPath : [Blob], keyName : Text) : async Text {

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let address = utils.publicKeyToAddress(publicKey);
    return address;
  };

};
