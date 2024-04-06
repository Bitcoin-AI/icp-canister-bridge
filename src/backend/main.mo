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

  let keyName = "dfx_test_key"; // this is for local network

  //let keyName = "test_key_1"; //This is for IC network

  let API_URL : Text = "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app";

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

  let petitions = HashMap.HashMap<Text, Types.PetitionEvent>(10, Text.equal, Text.hash);

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

  public shared (msg) func petitionEVM2EVM(petitionEvent : Types.PetitionEvent) : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let transactionId = petitionEvent.proofTxId;

    let resultTxDetails = await EVM.getTransactionDetails(transactionId, petitionEvent.sendingChain, transform);
    let txDetails = JSON.parse(resultTxDetails);

    let transactionToAddress = await utils.getValue(txDetails, "to");
    let receiverTransaction = utils.subText(transactionToAddress, 1, transactionToAddress.size() - 1);

    // let transactionData = await utils.getValue(txDetails, "to");
    let canisterAddress = await LN.getEvmAddr(derivationPath,keyName);

    let transactionData = await utils.getValue(txDetails, "input");

    // If there is no sentERC20 it is considered that he sent native coin, or if he is sending wbtc
    if (petitionEvent.sentERC == "0" or petitionEvent.wbtc == false) {
      if (receiverTransaction == "0x"#canisterAddress) {
        petitions.put(transactionId, petitionEvent);
        Debug.print("Petition created successfully");
        Debug.print("isWBTC: "#Bool.toText(petitionEvent.wbtc));
        Debug.print("sendingChain: "#petitionEvent.sendingChain);
        Debug.print("wantedAddress: "#petitionEvent.wantedAddress);
        Debug.print("wantedChain: "#petitionEvent.wantedChain);
        Debug.print("wantedERC20: "#petitionEvent.wantedERC20);
        Debug.print("sentERC20: "#petitionEvent.sentERC);

        return "Petition created successfully";
      } else {
        Debug.print("Bad transaction");
        return "Bad transaction";
      };
    } else {
      let decodedDataResult = await utils.decodeTransferERC20Data(transactionData);
      switch (decodedDataResult) {
        case (#ok((address, _))) {
          Debug.print("Canister Address: "#canisterAddress);
          Debug.print("ERC20 transfer data address: "#address);
          if ("0x"#canisterAddress == address) {
            // Check if receiver of ERC20 is the canister
            petitions.put(transactionId, petitionEvent);
            Debug.print("Petition for ERC20 transfer created successfully");
            return "Petition for ERC20 transfer created successfully";
          } else {
            Debug.print("Bad ERC20 transaction");
            return "Bad ERC20 transaction";
          };
        };
        case (#err(errorMsg)) {
          Debug.print("Error decoding ERC20 data: " # errorMsg);
          return "Error decoding transaction data";
        };
      };
    };
  };

  public shared (msg) func solvePetitionEVM2EVM(petitionTxId : Text, proofTxId : Text, signature : Text) : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    let petition = petitions.get(petitionTxId);

    switch (petition) {
      case (null) {
        return "No petition found for this transaction";
      };
      case (?petitionEvent) {
        let canisterAddress = await LN.getEvmAddr(derivationPath,keyName);

        let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));
        let reward : Nat = switch (Nat.fromText(petitionEvent.reward)) {
          case (null) { 0 };
          case (?value) { value };
        };
        Debug.print("Checking petiton event to be solved");

        let resultTxDetailsPetition = await EVM.getTransactionDetails(petitionTxId, petitionEvent.sendingChain, transform);
        let txDetailsPetition = JSON.parse(resultTxDetailsPetition);

        let transactionData = await utils.getValue(txDetailsPetition, "input");

        let transactionAmount = await utils.getValue(txDetailsPetition, "value");



      // Check the correct Amount depending if it was a ERC20 transaction or not
        let transactionNat : Nat = if (petitionEvent.wbtc == false or petitionEvent.sentERC == "0") {
          let transactionAmountNat64 = utils.hexStringToNat64(transactionAmount);
          Nat64.toNat(transactionAmountNat64);
        } else {

          let decodedDataResult = await utils.decodeTransferERC20Data(transactionData);
          switch (decodedDataResult) {
            case (#ok((_, amountNat))) { amountNat };
            case (#err(_)) { 0 };
          };
        };
        Debug.print("Amount that needs to be sent: "#Nat.toText(transactionNat));
        let isWBTC: Bool = switch(petitionEvent.wantedChain){
          case("0x1f"){
            false;
          };
          case(_){
            true;
          };
        };
        Debug.print("Validating transaction with parameters");
        Debug.print("isWBTC: "#Bool.toText(isWBTC));
        Debug.print("petitionEvent.wantedERC20: "#petitionEvent.wantedERC20);
        Debug.print("proofTxId: "#proofTxId);
        Debug.print("petitionEvent.wantedAddress: "#petitionEvent.wantedAddress);
        Debug.print("transactionNat: "#Nat.toText(transactionNat));
        Debug.print("petitionEvent.wantedChain: "#petitionEvent.wantedChain);

        let isValidTransaction = await EVM.validateTransaction(
          isWBTC,
          petitionEvent.wantedERC20,
          proofTxId,
          petitionEvent.wantedAddress, // Expected address
          transactionNat, // Expected amount
          petitionEvent.wantedChain,
          signature,
          transform,
        );
        Debug.print("Petition event transaction validation finished");
        if(isValidTransaction == false){
          Debug.print("Transaction Validation Failed");
        };
        Debug.print("Checking petition solve transaction");

        let resultTxDetailsProof = await EVM.getTransactionDetails(proofTxId, petitionEvent.wantedChain, transform);
        let proofTxDetails = JSON.parse(resultTxDetailsProof);

        let transactionSolver = await utils.getValue(proofTxDetails, "from");

        let transactionSenderCleaned = utils.subText(transactionSolver, 1, transactionSolver.size() - 1);
        Debug.print("Petition solve transaction being validated");

        if (isValidTransaction) {
          // if (reward > 0) {
          let transferResponse = await EVM.createAndSendTransaction(
            petitionEvent.sendingChain,
            petitionEvent.sentERC,
            isWBTC,
            derivationPath,
            keyName,
            canisterAddress,
            transactionSenderCleaned,
            reward + transactionNat,
            publicKey,
            transform,
          );
          let isError = await utils.getValue(JSON.parse(transferResponse), "error");
          switch (isError) {
            case ("") {
              let _ = petitions.remove(petitionTxId);

              Debug.print("Petition solved");

              return "Petition solved successfully and reward transferred";
            };
            case (errorValue) {
              Debug.print("Failed to transfer reward due to error: " # errorValue);
              return "Failed to transfer reward";
            };
          };
          // } else {
          //   return "No reward available for this petition";
          // };
        } else {
          Debug.print("Petition solve transaction failed");

          return "Transaction validation failed";
        };
      };
    };
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

    let address = await LN.getEvmAddr(derivationPath,keyName);
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
            let paymenttxDetails = JSON.parse(paymentResult);
            let errorField = await utils.getValue(paymenttxDetails, "error");
            let resultField = await utils.getValue(paymenttxDetails, "result");
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

  public query func getPetitions() : async [Types.PetitionEvent] {
    var entries: [Types.PetitionEvent] = [];
    for ((_, value) in petitions.entries()) {
      entries := Array.append(entries,[value]);
    };
    entries;
  };
};
