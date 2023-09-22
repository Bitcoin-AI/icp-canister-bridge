import RSK_testnet_mo "./rsk_testnet";
import lightning_testnet "./lightning_testnet";
import utils "utils";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import JSON "mo:json/JSON";
import Text "mo:base-0.7.3/Text";
import Debug "mo:base-0.7.3/Debug";

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
    // Check if payment is settled and get evm_address)
    let result = await utils.getValue(parsedResponse, "result");
    let evm_addr = await utils.getValue(JSON.parse(result), "memo");
    let isSettled = await utils.getValue(JSON.parse(result), "settled");
    let invoice = await utils.getValue(JSON.parse(result), "payment_request");

    if (isSettled == "false") {
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
    let sendTxResponse = await RSK_testnet_mo.swapFromLightningNetwork(derivationPath, keyName, evm_addr);

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
            // Invoice ID already exists in the map, you can update it if needed
            // For example, to update the amount:
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
      Debug.print("Amount: " # Nat.toText(amount));
      Debug.print("InvoiceId: " # invoiceId);

      // Check if invoice has correct amount

      let result = await utils.getValue(JSON.parse(await lightning_testnet.checkInvoice(invoiceId)), "result");
      let amountCheckedOpt : ?Nat = Nat.fromText(await utils.getValue(JSON.parse(result), "value"));

      Debug.print("amountCheckedOpt: " # invoiceId);

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
            let paymentResult = await lightning_testnet.payInvoice(invoiceId, derivationPath, keyName);
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
              // we can try again later if it was in process 
            };

          };
        };
      };
    };

  };

};
