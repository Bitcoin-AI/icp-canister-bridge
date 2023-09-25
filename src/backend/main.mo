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
  public func generateInvoiceToSwapToRsk(amount : Nat, address : Text) : async Text {
    let invoiceResponse = await lightning_testnet.generateInvoice(amount, address);
    return invoiceResponse;
  };

  public shared (msg) func swapFromLightningNetwork(payment_hash : Text) : async Text {

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let paymentCheckResponse = await lightning_testnet.checkInvoice(payment_hash);
    let parsedResponse = JSON.parse(paymentCheckResponse);
    // Check if payment is settled and get evm_address
    //let result = await utils.getValue(parsedResponse, "result");
    let evm_addr = await utils.getValue(parsedResponse, "memo");
    let isSettled = await utils.getValue(parsedResponse, "settled");
    let invoice = await utils.getValue(parsedResponse, "payment_request");
    let falseString: Text =  Bool.toText(false);

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
    let sendTxResponse = await RSK_testnet_mo.swapFromLightningNetwork(derivationPath, keyName, utils.subText(evm_addr, 1, evm_addr.size() - 1));

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

  public shared (msg) func getEvmAddr() : async Text {
    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let address = await lightning_testnet.getEvmAddr(derivationPath, keyName);
    return address;
  };

  //From RSK Blockchain to LightningNetwork
  public shared (msg) func payInvoicesAccordingToEvents() : async () {

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
        // Now you have paymentRequest and paymentHash
        // Replace all occurrences of '/' with '_' and '+' with '-'
        // let base64EncodedPaymentHash = Text.map(
        //   paymentHash,
        //   func(c) {
        //     if (c == '/') '_' else if (c == '+') '-' else c;
        //   },
        // );
        // Debug.print(base64EncodedPaymentHash);

        // Invoice Id is the r_hash in the blockchain
        let amountString = await utils.getValue(JSON.parse(await lightning_testnet.checkInvoice(invoiceId)), "value");

        let paymentRequest = await utils.getValue(JSON.parse(await lightning_testnet.checkInvoice(invoiceId)), "payment_request");

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
              let paymentResult = await lightning_testnet.payInvoice(paymentRequest, derivationPath, keyName);
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
