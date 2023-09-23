import RSK_testnet_mo "./rsk_testnet";
import lightning_testnet "./lightning_testnet";
import utils "utils";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
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
  let paymentHashToRequest = HashMap.HashMap<Text, (Text, Text)>(10, Text.equal, Text.hash);

  // From Lightning network to RSK blockchain
  public func generateInvoiceToSwapToRsk(amount : Nat, address : Text) : async Text {
    let invoiceResponse = await lightning_testnet.generateInvoice(amount, address);
    return invoiceResponse;
  };

  //From RSK blockchain to Lightning Network
  public func generateInvoiceToSwapToLN(amount : Nat) : async Text {
    let invoiceResponse = await lightning_testnet.generateInvoice(amount, "toLN");

    // Extract the paymentRequest and paymentHash from the invoiceResponse
    let paymentRequest = await utils.getValue(JSON.parse(invoiceResponse), "payment_request");
    let paymentHash = await utils.getValue(JSON.parse(invoiceResponse), "r_hash");

    let paymentRequestClean = utils.subText(paymentRequest,1, paymentRequest.size()-1);
    let paymentHashClean = utils.subText(paymentHash, 1, paymentHash.size()-1);

    // Generate the keccak256 hash of the paymentRequest
    let keccak256_hex = AU.toText(HU.keccak(TU.encodeUtf8(paymentRequest), 256));

    // Store both paymentRequest and paymentHash in the HashMap
    paymentHashToRequest.put(keccak256_hex, (paymentRequestClean, paymentHashClean));

    return "Hash: " # keccak256_hex # " Invoice Response: " # invoiceResponse;
  };

  public shared (msg) func swapFromLightningNetwork(payment_hash : Text) : async Text {

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let paymentCheckResponse = await lightning_testnet.checkInvoice(payment_hash);
    let parsedResponse = JSON.parse(paymentCheckResponse);
    // Check if payment is settled and get evm_address
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
      try {
        // Retrieve paymentRequest and paymentHash from the HashMap
        let paymentInfoOpt = paymentHashToRequest.get(invoiceId);

        switch (paymentInfoOpt) {
          case (null) {
            Debug.print("InvoiceId not found in the HashMap");
            // Skip to the next iteration
          };
          case (?(paymentRequest, paymentHash)) {
            // Now you have paymentRequest and paymentHash
            // Replace all occurrences of '/' with '_' and '+' with '-'
            let base64EncodedPaymentHash = Text.map(paymentHash, func(c) {
              if (c == '/') '_'
              else if(c == '+') '-'
              else c
            });
            Debug.print(base64EncodedPaymentHash);
            let result = await utils.getValue(JSON.parse(await lightning_testnet.checkInvoice(base64EncodedPaymentHash)), "result");

            let amountCheckedOpt : ?Nat = Nat.fromText(await utils.getValue(JSON.parse(result), "value"));

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
          };
        };
      }  catch(e: Error.Error) {
            Debug.print("Caught exception: " # Error.message(e));
      };
    };

  };
};
