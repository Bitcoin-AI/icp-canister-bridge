import RSK_testnet_mo "./rsk_testnet";
import lightning_testnet "./lightning_testnet";
import utils "utils";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Bool "mo:base/Bool";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import JSON "mo:json/JSON";
import Text "mo:base-0.7.3/Text";
import Debug "mo:base-0.7.3/Debug";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";

import HU "mo:evm-tx/utils/HashUtils";
import Types "Types";

actor {

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

  let paidInvoicestoRSK = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);
  let paidInvoicestoLN = HashMap.HashMap<Text, (Bool, Nat)>(10, Text.equal, Text.hash);
  let paidTransactions = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);

  // From Lightning network to RSK blockchain
  public func generateInvoiceToSwapToRsk(amount : Nat, address : Text, time : Text) : async Text {
    let invoiceResponse = await lightning_testnet.generateInvoice(amount, address, time, transform);
    return invoiceResponse;
  };
  /*
  public shared (msg) func swapFromLightningNetwork(hexChainId:Text,rpcUrl: Text,wbtcAddress:Text,payment_hash : Text, timestamp : Text) : async Text {

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let paymentCheckResponse = await lightning_testnet.checkInvoice(payment_hash, timestamp, transform);
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

    let isPaid = paidInvoicestoRSK.get(invoice);

    let isPaidBoolean : Bool = switch (isPaid) {
      case (null) { false };
      case (?true) { true };
      case (?false) { false };
    };

    if (isPaidBoolean) {
      return "Invoice is already paid and rsk transaction processed";
    };

    // Perform swap from Lightning Network to Ethereum
    let sendTxResponse = await RSK_testnet_mo.swapFromLightningNetwork(hexChainId,rpcUrl,wbtcAddress,derivationPath, keyName, utils.subText(evm_addr, 1, evm_addr.size() - 1), amount, transform);

    let isError = await utils.getValue(JSON.parse(sendTxResponse), "error");

    switch (isError) {
      case ("") {
        paidInvoicestoRSK.put(invoice, true);
      };
      case (errorValue) {
        Debug.print("Could not pay invoice tx error: " # errorValue);
      };
    };

    return sendTxResponse;
  };
  */
  type TransferEvent = {
     sendingChain : Text;
     recipientAddress : Text;
     recipientChain : Text;
     proofTxId : Text; // This will be the transaction where users send the funds to the canister contract address
  };
  public shared (msg) func swapEVM2EVM(hexChainId: Text,transferEvent: TransferEvent) : async Text {

    let keyName = "dfx_test_key";
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
    let sendTxResponse = await RSK_testnet_mo.swapEVM2EVM(hexChainId,transferEvent, derivationPath, keyName,  transform);

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


  public shared (msg) func swapLN2EVM(hexChainId: Text,payment_hash : Text, timestamp : Text) : async Text {

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let paymentCheckResponse = await lightning_testnet.checkInvoice(payment_hash, timestamp, transform);
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
    let sendTxResponse = await RSK_testnet_mo.swapLN2EVM(hexChainId,derivationPath, keyName, amount, utils.subText(evm_addr, 1, evm_addr.size() - 1),  transform);

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
    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let address = await lightning_testnet.getEvmAddr(derivationPath, keyName);
    return address;
  };

  public shared (msg) func getEvents() : async [Event] {

    let events : [Event] = await RSK_testnet_mo.readRSKSmartContractEvents(transform);

    return events;

  };

  //From RSK Blockchain to LightningNetwork
  public shared (msg) func payInvoicesAccordingToEvents(timestamp : Text) : async Text {
    var result : Text = "No actions taken";

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let events : [Event] = await RSK_testnet_mo.readRSKSmartContractEvents(transform);

    ignore Array.tabulate<Event>(
      Array.size(events),
      func(index : Nat) : Event {
        let event = events[index];
        let { address; amount } = event;
        switch (paidInvoicestoLN.get(address)) {
          case (null) {
            paidInvoicestoLN.put(address, (false, amount));
          };
          case (?(isPaid, existingAmount)) {
            //Do nothing
          };
        };
        return event;
      },
    );

    let unpaidInvoices = HashMap.mapFilter<Text, (Bool, Nat), (Bool, Nat)>(
      paidInvoicestoLN,
      Text.equal,
      Text.hash,
      func(key : Text, value : (Bool, Nat)) : ?(Bool, Nat) {
        let (isPaid, amount) = value;
        if (not isPaid) {
          return ?(isPaid, amount);
        };
        return null;
      },
    );

    let entries = unpaidInvoices.entries();
    for ((invoiceId, (isPaid, amount)) in entries) {
      try {
        let treatedRequest = Text.replace(invoiceId, #char 'E', "");
        let paymentRequest = utils.trim(treatedRequest);
        // let decodedPayReq = await lightning_testnet.decodePayReq(paymentRequest, timestamp, transform);
        // let payReqResponse = JSON.parse(decodedPayReq);
        // let amountString = await utils.getValue(payReqResponse, "num_satoshis");
        // let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
        let amountCheckedOpt : ?Nat = Nat.fromText("100" # "0000000000");

        switch (amountCheckedOpt) {
          case (null) {
            paidInvoicestoLN.put(invoiceId, (true, amount));
            result := "Failed to convert amountChecked to Nat. Skipping invoice.";
          };
          case (?amountChecked) {
            if (amountChecked > amountChecked) {
              paidInvoicestoLN.put(invoiceId, (true, amount));
              result := "Amount mismatch. Marking as paid to skip.";
            } else {
              let paymentResult = await lightning_testnet.payInvoice(paymentRequest, derivationPath, keyName, timestamp, transform);
              let paymentResultJson = JSON.parse(paymentResult);
              let errorField = await utils.getValue(paymentResultJson, "error");
              let resultField = await utils.getValue(paymentResultJson, "result");
              let statusField = await utils.getValue(JSON.parse(resultField), "status");

              if (errorField == "" and statusField == "SUCCEEDED") {
                paidInvoicestoLN.put(invoiceId, (true, amount));
                result := "Payment Result: Successful";
              } else {
                // For now just skip any error
                paidInvoicestoLN.put(invoiceId, (true, amount));
                result := "Payment Result: Failed";
              };
            };
          };
        };
      } catch (e : Error.Error) {
        // For now just skip any error
        paidInvoicestoLN.put(invoiceId, (true, amount));

        result := "Caught exception: " # Error.message(e);
      };
    };

    return result;
  };
};
