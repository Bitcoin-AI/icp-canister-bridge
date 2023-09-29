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

actor {

  type JSONField = (Text, JSON.JSON);

  type Event = {
    address : Text;
    amount : Nat;
  };

  let paidInvoicestoRSK = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);
  let paidInvoicestoLN = HashMap.HashMap<Text, (Bool, Nat)>(10, Text.equal, Text.hash);

  // From Lightning network to RSK blockchain
  public func generateInvoiceToSwapToRsk(amount : Nat, address : Text, time:Text) : async Text {
    let invoiceResponse = await lightning_testnet.generateInvoice(amount, address, time);
    return invoiceResponse;
  };

  public shared (msg) func swapFromLightningNetwork(payment_hash : Text,timestamp:Text) : async Text {

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let paymentCheckResponse = await lightning_testnet.checkInvoice(payment_hash,timestamp);
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
    let sendTxResponse = await RSK_testnet_mo.swapFromLightningNetwork(derivationPath, keyName, utils.subText(evm_addr, 1, evm_addr.size() - 1), amount);

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

  public func decodePayReq(payment_request: Text,timestamp: Text): async Text{
    let response = await lightning_testnet.decodePayReq(payment_request,timestamp);
    return response;
  };

  public shared (msg) func getEvmAddr() : async Text {
    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let address = await lightning_testnet.getEvmAddr(derivationPath, keyName);
    return address;
  };



  //From RSK Blockchain to LightningNetwork
  public shared (msg) func payInvoicesAccordingToEvents(timestamp: Text) : async () {

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let events : [Event] = await RSK_testnet_mo.readRSKSmartContractEvents();

    // Using Array.tabulate to iterate over the events
    ignore Array.tabulate<Event>(
      Array.size(events),
      func(index : Nat) : Event {
        let event = events[index];
        let { address; amount } = event;
        switch (paidInvoicestoLN.get(address)) {
          case (null) {
            // Invoice ID not found in the map, add it
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

    // Process each unpaid invoice
    let entries = unpaidInvoices.entries();
    for ((invoiceId, (isPaid, amount)) in entries) {
      Debug.print("Checking invoice" # invoiceId # "with amount: " # Nat.toText(amount));

      try {
        let treatedRequest = Text.replace(invoiceId, #char 'E', "");
        let paymentRequest = utils.trim(treatedRequest);
        let decodedPayReq = await lightning_testnet.decodePayReq(paymentRequest,timestamp);
        let payReqResponse = JSON.parse(decodedPayReq);
        let amountString = await utils.getValue(payReqResponse, "num_satoshis");
        let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
        let amountCheckedOpt : ?Nat = Nat.fromText(cleanAmountString # "0000000000");

        switch (amountCheckedOpt) {
          case (null) {
            paidInvoicestoLN.put(invoiceId, (true, amount));
            Debug.print("Failed to convert amountChecked to Nat. Skipping invoice.");
          };
          case (?amountChecked) {
            if (amountChecked != amount) {
              // Update the HashMap to set status = paid if the amount is incorrect
              paidInvoicestoLN.put(invoiceId, (true, amount));
              Debug.print("Amount mismatch. Marking as paid to skip.");
            } else {
              // Proceed to pay the invoice
              let paymentResult = await lightning_testnet.payInvoice(paymentRequest, derivationPath, keyName,timestamp);
              Debug.print("Payment result: " # paymentResult);

              let paymentResultJson = JSON.parse(paymentResult);
              let errorField = await utils.getValue(paymentResultJson, "error");
              let resultField = await utils.getValue(paymentResultJson, "result");
              let statusField = await utils.getValue(JSON.parse(resultField), "status");

              if (errorField == "" and statusField == "SUCCEEDED") {
                Debug.print("Payment Result: Successful");
                // Update the HashMap to set status = paid
                paidInvoicestoLN.put(invoiceId, (true, amount));
              } else {
                Debug.print("Payment Result: Failed");
                // We can try again later if it was in process
              };
            };
          };
        };
      } catch (e : Error.Error) {
        Debug.print("Caught exception: " # Error.message(e));
      };
    };

  };
};
