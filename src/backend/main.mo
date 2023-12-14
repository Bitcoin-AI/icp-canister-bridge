import RSK_testnet_mo "./rsk_testnet";
import lightning_testnet "./lightning_testnet";
import utils "utils";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import JSON "mo:json/JSON";
import Text "mo:base-0.7.3/Text";
import Debug "mo:base-0.7.3/Debug";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";

import HU "mo:evm-tx/utils/HashUtils";
import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";
import Types "Types";

actor {

  let keyName = "dfx_test_key"; // this is for local network

  // let keyName = "test_key_1";    This is for IC network

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

  let paidTransactions = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);
  let paidInvoicestoLN = HashMap.HashMap<Text, (Bool, Nat)>(10, Text.equal, Text.hash);

  // From Lightning network to RSK blockchain
  public func generateInvoiceToSwapToRsk(amount : Nat, address : Text, time : Text) : async Text {
    let invoiceResponse = await lightning_testnet.generateInvoice(amount, address, time, transform);
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
    let sendTxResponse = await RSK_testnet_mo.swapEVM2EVM(transferEvent : Types.TransferEvent, derivationPath, keyName, transform);

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

  public shared (msg) func swapEVM2LN(transferEvent : Types.TransferEvent, timestamp : Text) : async Text {

    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let signerAddress = utils.publicKeyToAddress(publicKey);

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

    let transactionDetailsPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionByHash\",  \"method\": \"eth_getTransactionByHash\" , \"params\": [\"" # transactionId # "\"] }";
    let responseTransactionDetails : Text = await utils.httpRequest(?transactionDetailsPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", null, "post", transform);
    let parsedTransactionDetails = JSON.parse(responseTransactionDetails);

    // Not sure if it is to here
    let transactionProof = await utils.getValue(parsedTransactionDetails, "to");

    let transactionAmount = await utils.getValue(parsedTransactionDetails, "value");

    let transactionNat = Nat64.toNat(utils.hexStringToNat64(transactionAmount));

    if (transactionProof == signerAddress) {

    } else {
      Debug.print("Transaction does not match the criteria");
      return "Not valid transaction";
    };

    var result : Text = "";

    let invoiceIdOpt = transferEvent.invoiceId;
    var treatedRequest : Text = "";

    switch (invoiceIdOpt) {
      case (null) {
        // Handle the case where invoiceId is null
        // You can assign a default value or handle it as per your logic
        treatedRequest := ""; // Example: default to an empty string if invoiceId is null
      };
      case (?invoiceId) {
        // invoiceId is not null and can be safely used
        treatedRequest := invoiceId;
      };
    };

    try {

      let paymentRequest = utils.trim(treatedRequest);

      // TODO:  check why this was not working before, or if it is working now

      // let decodedPayReq = await lightning_testnet.decodePayReq(paymentRequest, timestamp, transform);
      // let payReqResponse = JSON.parse(decodedPayReq);
      // let amountString = await utils.getValue(payReqResponse, "num_satoshis");
      // let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
      let amountCheckedOpt : ?Nat = Nat.fromText("100" # "0000000000");

      switch (amountCheckedOpt) {
        case (null) {
          paidInvoicestoLN.put(treatedRequest, (true, transactionNat));
          result := "Failed to convert amountChecked to Nat. Skipping invoice.";
        };
        case (?amountChecked) {
          if (amountChecked > amountChecked) {
            paidInvoicestoLN.put(treatedRequest, (true, transactionNat));
            result := "Amount mismatch. Marking as paid to skip.";
          } else {
            let paymentResult = await lightning_testnet.payInvoice(paymentRequest, derivationPath, keyName, timestamp, transform);
            let paymentResultJson = JSON.parse(paymentResult);
            let errorField = await utils.getValue(paymentResultJson, "error");
            let resultField = await utils.getValue(paymentResultJson, "result");
            let statusField = await utils.getValue(JSON.parse(resultField), "status");

            if (errorField == "" and statusField == "SUCCEEDED") {
              paidInvoicestoLN.put(treatedRequest, (true, transactionNat));
              result := "Payment Result: Successful";
            } else {
              // For now just skip any error
              paidInvoicestoLN.put(treatedRequest, (true, transactionNat));
              result := "Payment Result: Failed";
            };
          };
        };
      };
    } catch (e : Error.Error) {
      // For now just skip any error
      paidInvoicestoLN.put(treatedRequest, (true, transactionNat));

      result := "Caught exception: " # Error.message(e);
    };

    return result;
  };

  public shared (msg) func swapLN2EVM(transferEvent : Types.TransferEvent, timestamp : Text) : async Text {

    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    let payment_hash = transferEvent.invoiceId;

    var paymentHash : Text = "";

    switch (payment_hash) {
      case (null) {
        // Handle the case where invoiceId is null
        // You can assign a default value or handle it as per your logic
        paymentHash := "";
        return "No Invoice Id declared";
      };
      case (?invoiceId) {
        // invoiceId is not null and can be safely used
        paymentHash := invoiceId;
      };
    };

    let paymentCheckResponse = await lightning_testnet.checkInvoice(paymentHash, timestamp, transform);
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
    let sendTxResponse = await RSK_testnet_mo.swapLN2EVM(derivationPath, keyName, amount, transferEvent, transform);

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
    let response = await lightning_testnet.decodePayReq(payment_request, timestamp, transform);
    return response;
  };

  public shared (msg) func getEvmAddr() : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let address = await lightning_testnet.getEvmAddr(derivationPath, keyName);
    return address;
  };

  // public shared (msg) func getEvents() : async [Event] {

  //   let events : [Event] = await RSK_testnet_mo.readRSKSmartContractEvents(transform);

  //   return events;

  // };

  // No longer used since we wont be using contracts

  //From RSK Blockchain to LightningNetwork
  // refactor this function to use fewer lines of code.
  // public shared (msg) func payInvoicesAccordingToEvents(timestamp : Text) : async Text {
  //   var result : Text = "No actions taken";

  //   let keyName = "test_key_1";
  //   let principalId = msg.caller;
  //   let derivationPath = [Principal.toBlob(principalId)];
  //   let events : [Event] = await RSK_testnet_mo.readRSKSmartContractEvents(transform);

  //   ignore Array.tabulate<Event>(
  //     Array.size(events),
  //     func(index : Nat) : Event {
  //       let event = events[index];
  //       let { address; amount } = event;
  //       switch (paidInvoicestoLN.get(address)) {
  //         case (null) {
  //           paidInvoicestoLN.put(address, (false, amount));
  //         };
  //         case (?(isPaid, existingAmount)) {
  //           //Do nothing
  //         };
  //       };
  //       return event;
  //     },
  //   );

  //   let unpaidInvoices = HashMap.mapFilter<Text, (Bool, Nat), (Bool, Nat)>(
  //     paidInvoicestoLN,
  //     Text.equal,
  //     Text.hash,
  //     func(key : Text, value : (Bool, Nat)) : ?(Bool, Nat) {
  //       let (isPaid, amount) = value;
  //       if (not isPaid) {
  //         return ?(isPaid, amount);
  //       };
  //       return null;
  //     },
  //   );

  //   let entries = unpaidInvoices.entries();
  //   for ((invoiceId, (isPaid, amount)) in entries) {
  //     try {
  //       let treatedRequest = Text.replace(invoiceId, #char 'E', "");
  //       let paymentRequest = utils.trim(treatedRequest);
  //       // let decodedPayReq = await lightning_testnet.decodePayReq(paymentRequest, timestamp, transform);
  //       // let payReqResponse = JSON.parse(decodedPayReq);
  //       // let amountString = await utils.getValue(payReqResponse, "num_satoshis");
  //       // let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
  //       let amountCheckedOpt : ?Nat = Nat.fromText("100" # "0000000000");

  //       switch (amountCheckedOpt) {
  //         case (null) {
  //           paidInvoicestoLN.put(invoiceId, (true, amount));
  //           result := "Failed to convert amountChecked to Nat. Skipping invoice.";
  //         };
  //         case (?amountChecked) {
  //           if (amountChecked > amountChecked) {
  //             paidInvoicestoLN.put(invoiceId, (true, amount));
  //             result := "Amount mismatch. Marking as paid to skip.";
  //           } else {
  //             let paymentResult = await lightning_testnet.payInvoice(paymentRequest, derivationPath, keyName, timestamp, transform);
  //             let paymentResultJson = JSON.parse(paymentResult);
  //             let errorField = await utils.getValue(paymentResultJson, "error");
  //             let resultField = await utils.getValue(paymentResultJson, "result");
  //             let statusField = await utils.getValue(JSON.parse(resultField), "status");

  //             if (errorField == "" and statusField == "SUCCEEDED") {
  //               paidInvoicestoLN.put(invoiceId, (true, amount));
  //               result := "Payment Result: Successful";
  //             } else {
  //               // For now just skip any error
  //               paidInvoicestoLN.put(invoiceId, (true, amount));
  //               result := "Payment Result: Failed";
  //             };
  //           };
  //         };
  //       };
  //     } catch (e : Error.Error) {
  //       // For now just skip any error
  //       paidInvoicestoLN.put(invoiceId, (true, amount));

  //       result := "Caught exception: " # Error.message(e);
  //     };
  //   };

  //   return result;
  // };
};
