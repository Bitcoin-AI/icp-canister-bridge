import EVM "./evm";
import LN "./ln";
import utils "utils";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";

import Error "mo:base/Error";
import JSON "mo:json/JSON";
import Text "mo:base-0.7.3/Text";
import Debug "mo:base-0.7.3/Debug";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";

import HU "mo:evm-tx/utils/HashUtils";
import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";
import Types "Types";

actor {

  // let keyName = "dfx_test_key"; // this is for local network

  let keyName = "test_key_1";    //This is for IC network

  public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
    let transformed : Types.CanisterHttpResponsePayload = {
      status = raw.response.status;
      body = raw.response.body;

      headers = [
        {
          name = "Content-Security-Policy";
          value = "default-src 'self'";
        },
        { name = "Referrer-Policy"; value = "strict-origin" },
        { name = "Permissions-Policy"; value = "geolocation=(self)" },
        {
          name = "Strict-Transport-Security";
          value = "max-age=63072000";
        },
        { name = "X-Frame-Options"; value = "DENY" },
        { name = "X-Content-Type-Options"; value = "nosniff" },
      ];
    };
    transformed;
  };

  type JSONField = (Text, JSON.JSON);

  type Event = {
    address : Text;
    amount : Nat;
  };

  let paidInvoicestoLN = HashMap.HashMap<Text, (Bool, Nat)>(10, Text.equal, Text.hash);
  let paidTransactions = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);

  // From Lightning network to RSK blockchain
  public func generateInvoiceToSwapToRsk(amount : Nat, address : Text, time : Text) : async Text {
    let invoiceResponse = await LN.generateInvoice(amount, address, time, transform);
    return invoiceResponse;
  };

  public shared (msg) func swapEVM2EVM(transferEvent : Types.TransferEvent) : async Text {

    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    let transactionId = transferEvent.proofTxId;

    let isPaid = paidTransactions.get(transactionId);

    let isPaidBoolean : Bool = switch (isPaid) {
      case (null) { false };
      case (?true) { true };
      case (?false) { false };
    };

    if (isPaidBoolean) {
      return "Transaction/ Invoice is already paid";
    };

    // Perform swap from Lightning Network to EVM or to Any other EVM compatible chain to another EVM
    let sendTxResponse = await EVM.swapEVM2EVM(transferEvent : Types.TransferEvent, derivationPath, keyName, transform);

    let isError = await utils.getValue(JSON.parse(sendTxResponse), "error");

    switch (isError) {
      case ("") {
        paidTransactions.put(transactionId, true);
      };
      case (errorValue) {
        Debug.print("Could not pay invoice tx error: " # errorValue);
      };
    };

    return sendTxResponse;
  };

  public shared (msg) func swapLN2EVM(hexChainId : Text, payment_hash : Text, timestamp : Text) : async Text {

    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let paymentCheckResponse = await LN.checkInvoice(payment_hash, timestamp, transform);
    let parsedResponse = JSON.parse(paymentCheckResponse);
    let evm_addr = await utils.getValue(parsedResponse, "memo");
    let isSettled = await utils.getValue(parsedResponse, "settled");
    let invoice = await utils.getValue(parsedResponse, "payment_request");

    let amountSatoshi = await utils.getValue(parsedResponse, "value");
    Debug.print(amountSatoshi);
    let amount : Nat = switch (Nat.fromText(utils.subText(amountSatoshi, 1, amountSatoshi.size() - 1) # "0000000000")) {

      case (null) { 0 };
      case (?value) { value };
    };
    Debug.print(Nat.toText(amount));
    let falseString : Text = Bool.toText(false);

    if (isSettled == falseString) {
      return "Invoice not settled, pay invoice and try again";
    };

    let isPaid = paidTransactions.get(invoice);

    let isPaidBoolean : Bool = switch (isPaid) {
      case (null) { false };
      case (?true) { true };
      case (?false) { false };
    };

    if (isPaidBoolean) {
      return "Transaction/ Invoice is already paid";
    };

    // Perform swap from Lightning Network to EVM or to Any other EVM compatible chain to another EVM
    let sendTxResponse = await EVM.swapLN2EVM(hexChainId, derivationPath, keyName, amount, utils.subText(evm_addr, 1, evm_addr.size() - 1), transform);

    let isError = await utils.getValue(JSON.parse(sendTxResponse), "error");

    switch (isError) {
      case ("") {
        paidTransactions.put(invoice, true);
      };
      case (errorValue) {
        Debug.print("Could not pay invoice tx error: " # errorValue);
      };
    };

    return sendTxResponse;
  };

  public func decodePayReq(payment_request : Text, timestamp : Text) : async Text {
    let response = await LN.decodePayReq(payment_request, timestamp, transform);
    return response;
  };

  public shared (msg) func getEvmAddr() : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let address = await LN.getEvmAddr(derivationPath, keyName);
    return address;
  };

  public shared (msg) func swapEVM2LN(transferEvent : Types.TransferEvent, timestamp : Text) : async Text {

    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let signerAddress = utils.publicKeyToAddress(publicKey);
    Debug.print(signerAddress);
    let transactionId = transferEvent.proofTxId;

    let isPaid = paidTransactions.get(transactionId);

    let isPaidBoolean : Bool = switch (isPaid) {
      case (null) { false };
      case (?true) { true };
      case (?false) { false };
    };

    if (isPaidBoolean) {
      return "Transaction/ Invoice is already paid";
    };
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "chain-id"; value = transferEvent.sendingChain },
    ];
    let transactionDetailsPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionByHash\", \"params\": [\"" # transactionId # "\"] }";
    let responseTransactionDetails : Text = await utils.httpRequest(?transactionDetailsPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", ?requestHeaders, "post", transform);
    let parsedTransactionDetails = JSON.parse(responseTransactionDetails);
    let txResult = await utils.getValue(parsedTransactionDetails, "result");
    let parsedTxResult = JSON.parse(txResult);
    let transactionProof = await utils.getValue(parsedTxResult, "to");
    Debug.print(transactionProof);
    let transactionAmount = await utils.getValue(parsedTxResult, "amount");

    let transactionNat = Nat64.toNat(utils.hexStringToNat64(transactionAmount));

    let transactionSender = await utils.getValue(parsedTxResult, "from");

    let transactionSenderCleaned = utils.subText(transactionSender, 1, transactionSender.size() - 1);

    let isCorrectSignature = await EVM.checkSignature(transferEvent.proofTxId, transactionSenderCleaned, transferEvent.signature);

    if (isCorrectSignature == false) {
      Debug.print("Transaction does not match the criteria");
      return "Wrong Signature";
    };

    var result : Text = "";

    let invoiceId = transferEvent.invoiceId;

    try {

      let paymentRequest = utils.trim(invoiceId);

      // TODO:  check why this was not working before, or if it is working now
      Debug.print(paymentRequest);
      let decodedPayReq = await LN.decodePayReq(paymentRequest, timestamp, transform);
      let payReqResponse = JSON.parse(decodedPayReq);
      let amountString = await utils.getValue(payReqResponse, "num_satoshis");
      let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
      Debug.print("Satoshis: " #amountString);
      Debug.print("cleanAmountString: " #cleanAmountString);
      let amountCheckedOpt : ?Nat = Nat.fromText(cleanAmountString # "0000000000");
      switch (amountCheckedOpt) {
        case (null) {
          paidInvoicestoLN.put(invoiceId, (true, transactionNat));
          result := "Failed to convert amountChecked to Nat. Skipping invoice.";
        };
        case (?amountChecked) {
          if (amountChecked > amountChecked) {
            paidInvoicestoLN.put(invoiceId, (true, transactionNat));
            result := "Amount mismatch. Marking as paid to skip.";
          } else {
            let paymentResult = await LN.payInvoice(paymentRequest, derivationPath, keyName, timestamp, transform);
            Debug.print(paymentResult);
            let paymentResultJson = JSON.parse(paymentResult);
            let errorField = await utils.getValue(paymentResultJson, "error");
            let resultField = await utils.getValue(paymentResultJson, "result");
            let statusField = await utils.getValue(JSON.parse(resultField), "status");
            Debug.print(statusField);
            if (Text.contains(paymentResult, #text "SUCCEEDED")) {
              paidInvoicestoLN.put(invoiceId, (true, transactionNat));
              paidTransactions.put(transactionId, true);

              result := "Payment Result: Successful";
            } else {
              // paidInvoicestoLN.put(invoiceId, (true, transactionNat));
              // paidTransactions.put(transactionId, true);

              result := "Payment Result: Failed";
            };
          };
        };
      };
    } catch (e : Error.Error) {
      // paidInvoicestoLN.put(invoiceId, (true, transactionNat));
      // paidTransactions.put(transactionId, true);

      result := "Caught exception: " # Error.message(e);
    };

    return result;
  };
};
