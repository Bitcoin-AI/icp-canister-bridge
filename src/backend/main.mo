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

  //  Add liquidty variables

  type ChainId = Text;
  type PrincipalIdText = Text;
  var totalLiquidityLN : Nat = 0;
  let totalLiquidityEVM = HashMap.HashMap<ChainId, Nat>(10, Text.equal, Text.hash);

  let feePercentage : Nat = 1; // 1%

  let liquidityProvidersLN = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
  let liquidityProvidersEVM = HashMap.HashMap<ChainId, HashMap.HashMap<PrincipalIdText, Nat>>(10, Text.equal, Text.hash);

  let providerFeesLN = HashMap.HashMap<Text, Nat>(10, Text.equal, Text.hash);
  let providerFeesEVM = HashMap.HashMap<ChainId, HashMap.HashMap<PrincipalIdText, Nat>>(10, Text.equal, Text.hash);

  var totalAccumulatedFeesLN : Nat = 0;
  let totalAccumulatedFeesEVM = HashMap.HashMap<ChainId, Nat>(10, Text.equal, Text.hash);

  let keyName = "dfx_test_key"; // this is for local network

  let userLastAccumulatedFeesEVM = HashMap.HashMap<ChainId, HashMap.HashMap<PrincipalIdText, Nat>>(10, Text.equal, Text.hash);

  //let keyName = "test_key_1"; //This is for IC network

  let API_URL : Text = "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app";
  let falseString : Text = Bool.toText(false);

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

  func calculateFee(amount : Nat) : Nat {
    return amount * feePercentage / 100;
  };

  type JSONField = (Text, JSON.JSON);

  type Event = {
    address : Text;
    amount : Nat;
  };

  let paidInvoicestoLN = HashMap.HashMap<Text, (Bool, Nat)>(10, Text.equal, Text.hash);
  let paidTransactions = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);

  let petitions = HashMap.HashMap<Text, Types.PetitionEvent>(10, Text.equal, Text.hash);
  let petitionUsed = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);

  let solvePetitionCreatorPaid = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);

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

    // let isPaidBoolean : Bool = switch (isPaid) {
    //   case (null) { false };
    //   case (?true) { true };
    //   case (?false) { false };
    // };

    // if (isPaidBoolean) {
    //   return "Transaction/ Invoice is already paid";
    // };

    // Fetch the transaction details from the sending chain
    let resultTxDetails = await EVM.getTransactionDetails(transactionId, transferEvent.sendingChain, transform);
    Debug.print("resultTxDetails: " #resultTxDetails); // Debug message

   
    let txDetails = JSON.parse(resultTxDetails);

    let transactionAmount = await utils.getValue(txDetails, "value");
    let transactionData = await utils.getValue(txDetails, "input");

    Debug.print("transactionAmount: " #transactionAmount); // Debug message

    var transactionNat : Nat = 0;

    if (transferEvent.sentERC20 == "0") {
      // Comparison uses '=='
      // Native token transfer
      let transactionAmountNat64 = utils.hexStringToNat64(transactionAmount);
      transactionNat := Nat64.toNat(transactionAmountNat64); // Correct conversion
    } else {
      // ERC20 transfer
      let decodedDataResult = await utils.decodeTransferERC20Data(transactionData);
      switch (decodedDataResult) {
        case (#ok((_, amountNat))) {
          transactionNat := amountNat; // Correct case assignment
        };
        case (#err(errMsg)) {
          Debug.print("Error decoding ERC20 data: " # errMsg); // Debug message
          return "Error decoding transaction data"; // Error handling
        };
      };
    };

    let feeAmount = calculateFee(transactionNat);

    Debug.print("transactionNat: " #Nat.toText(transactionNat)); // Debug message

    Debug.print("feeAmount: " # Nat.toText(feeAmount)); // Debug message

    let amountAfterFee = Nat.sub(transactionNat, feeAmount);

    // Accumulate the fee for the  wanted chain (the chain the funds are going to)
    let chainId = transferEvent.recipientChain;

    let currentAccumulatedFees = totalAccumulatedFeesEVM.get(chainId);
    let newAccumulatedFees = switch (currentAccumulatedFees) {
      case (null) { feeAmount };
      case (?existingAmount) { existingAmount + feeAmount };
    };

    Debug.print("newAccoumulated fees: " # Nat.toText(newAccumulatedFees)); // Debug message

    Debug.print("chainId: " # chainId); // Debug message

    totalAccumulatedFeesEVM.put(chainId, newAccumulatedFees);

    // Perform swap from Lightning Network to EVM or to Any other EVM compatible chain to another EVM

    // Now, perform the swap with amountAfterFee
    // We'll need to create and send a transaction to the desired chain with amountAfterFee

    // Get the canister's EVM address
    let canisterAddress = await LN.getEvmAddr(derivationPath, keyName);

    // Get the public key
    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    // Prepare the transfer parameters
    let sendingChainId = transferEvent.recipientChain; // The chain we're sending to
    let destinationAddress = transferEvent.recipientAddress;
    let tokenAddress = transferEvent.wantedERC20; // The token to send; "0" for native coin

    // Create and send the transaction
    let transferResponse = await EVM.createAndSendTransaction(
      sendingChainId,
      tokenAddress,
      derivationPath,
      keyName,
      canisterAddress,
      destinationAddress,
      amountAfterFee,
      publicKey,
      transform,
    );

    //Handle the error
    let isError = await utils.getValue(JSON.parse(transferResponse), "error");

    switch (isError) {
      case ("") {
        paidTransactions.put(transactionId, true);
      };
      case (errorValue) {
        Debug.print("Could not pay invoice tx error: " # errorValue);
      };
    };

    return transferResponse;
  };

  public shared (msg) func petitionLN2EVM(petitionEvent : Types.PetitionEvent, payment_hash : Text, timestamp : Text) : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let paymentCheckResponse = await LN.checkInvoice(payment_hash, timestamp, transform);
    let parsedResponse = JSON.parse(paymentCheckResponse);
    let isSettled = await utils.getValue(parsedResponse, "settled");
    let invoicePaidUncleaned = await utils.getValue(parsedResponse, "payment_request");
    let invoicePaid = utils.subText(invoicePaidUncleaned, 1, invoicePaidUncleaned.size() -1);
    Debug.print("Checking payment of invoice " #invoicePaid);
    let isPetitionRegistered : Bool = switch (petitionUsed.get(invoicePaid)) {
      case (null) { false };
      case (?true) { true };
      case (?false) { false };
    };

    if (isPetitionRegistered) {
      return "Petition already registered";
    };
    let amountSatoshi = await utils.getValue(parsedResponse, "value");
    Debug.print("Satoshis sent: " #amountSatoshi);
    let amount : Nat = switch (Nat.fromText(utils.subText(amountSatoshi, 1, amountSatoshi.size() - 1) # "0000000000")) {

      case (null) { 0 };
      case (?value) { value };
    };
    Debug.print(Nat.toText(amount));

    if (isSettled == falseString) {
      Debug.print("Invoice not settled, pay invoice and try again");
      return "Invoice not settled, pay invoice and try again";
    };
    Debug.print("Creating petition with invoicePaid: " #invoicePaid);
    petitions.put(invoicePaid, petitionEvent);
    petitionUsed.put(invoicePaid, true);
    Debug.print("Petition for LN to EVM transfer created successfully");
    return "Petition for LN to EVM transfer created successfully";
  };

  public shared (msg) func solvePetitionLN2EVM(
    petitionInvoiceId : Text,
    solvePetitionInvoice : Text,
    proofTxId : Text,
    signature : Text,
    timestamp : Text,
  ) : async Text {

    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    let petition = petitions.get(petitionInvoiceId);
    var result : Text = "";
    switch (petition) {
      case (null) {
        result := "No petition found for this transaction";
      };
      case (?petitionEvent) {
        let canisterAddress = await LN.getEvmAddr(derivationPath, keyName);

        let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));
        let reward : Nat = switch (Nat.fromText(petitionEvent.reward)) {
          case (null) { 0 };
          case (?value) { value };
        };
        Debug.print("Checking LN petiton event to be solved");

        let decodedPayReq = await LN.decodePayReq(petitionInvoiceId, timestamp, transform);
        let payReqResponse = JSON.parse(decodedPayReq);
        let amountString = await utils.getValue(payReqResponse, "num_satoshis");
        let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
        let transactionNat : Nat = switch (Nat.fromText(cleanAmountString)) {
          case (null) { 0 }; // Handle the case where the value is null
          case (?value) { value }; // Extract the Nat value if it is not null
        };
        Debug.print("Amount that needs to be sent: " #Nat.toText(transactionNat) # " satoshis");
        Debug.print("Converted to wei: " #Nat.toText(transactionNat * 10 ** 10));
        let isWBTC : Bool = switch (petitionEvent.wantedChain) {
          case ("0x1f") {
            false;
          };
          case (_) {
            true;
          };
        };
        Debug.print("Validating transaction with parameters");
        Debug.print("isWBTC: " #Bool.toText(isWBTC));
        Debug.print("petitionEvent.wantedERC20: " #petitionEvent.wantedERC20);
        Debug.print("proofTxId: " #proofTxId);
        Debug.print("petitionEvent.wantedAddress: " #petitionEvent.wantedAddress);
        Debug.print("transactionNat: " #Nat.toText(transactionNat * 10 ** 10));
        Debug.print("petitionEvent.wantedChain: " #petitionEvent.wantedChain);

        let isValidTransaction = await EVM.validateTransaction(
          petitionEvent.wantedERC20,
          proofTxId,
          "0x" #canisterAddress, // Expected address to be canister, after ok release payments
          transactionNat * 10 ** 10, // Expected amount
          petitionEvent.wantedChain,
          signature,
          transform,
        );
        Debug.print("Petition event transaction validation finished");

        Debug.print("Checking petition solve transaction");

        let resultTxDetailsProof = await EVM.getTransactionDetails(proofTxId, petitionEvent.wantedChain, transform);
        let proofTxDetails = JSON.parse(resultTxDetailsProof);

        let transactionSolver = await utils.getValue(proofTxDetails, "from");

        let transactionSenderCleaned = utils.subText(transactionSolver, 1, transactionSolver.size() - 1);
        Debug.print("Petition solve transaction being validated");

        if (isValidTransaction) {
          // Check if petition creator has been paid
          let petitionCreatorPaid : Bool = switch (solvePetitionCreatorPaid.get(petitionInvoiceId)) {
            case (null) { false };
            case (?true) { true };
            case (?false) { false };
          };
          Debug.print("Petiton creator paid before: " #Bool.toText(petitionCreatorPaid));

          if (petitionCreatorPaid == false) {
            Debug.print("Paying petition creator");
            // Pay petition creator
            let transferResponsePetitionCreator = await EVM.createAndSendTransaction(
              petitionEvent.wantedChain,
              petitionEvent.wantedERC20,
              derivationPath,
              keyName,
              canisterAddress,
              petitionEvent.wantedAddress,
              reward +(transactionNat * 10 ** 10),
              publicKey,
              transform,
            );
            let isErrorPetitionCreator = await utils.getValue(JSON.parse(transferResponsePetitionCreator), "error");
            switch (isErrorPetitionCreator) {
              case ("") {
                solvePetitionCreatorPaid.put(petitionInvoiceId, true);
                Debug.print("Petition creator received transfer");
              };
              case (errorValue) {
                Debug.print("Failed to transfer reward to creator due to error: " # errorValue);
                return "Failed to transfer to petition creator";
              };
            };
          };

          let paymentResult = await LN.payInvoice(solvePetitionInvoice, derivationPath, keyName, timestamp, transform);
          Debug.print(paymentResult);
          let paymenttxDetails = JSON.parse(paymentResult);
          let errorField = await utils.getValue(paymenttxDetails, "error");
          let resultField = await utils.getValue(paymenttxDetails, "result");
          let statusField = await utils.getValue(JSON.parse(resultField), "status");
          Debug.print(statusField);
          if (Text.contains(paymentResult, #text "SUCCEEDED")) {
            Debug.print("Payment Result: Successful");
            let _ = petitions.remove(petitionInvoiceId);

            result := "Payment Result: Successful";
          } else {
            Debug.print("Payment Result: Failed");
            result := "Payment Result: Failed";
          };
        } else {
          Debug.print("Petition solve transaction failed");

          result := "Transaction validation failed";
        };
      };
    };
    return result;
  };

  public shared (msg) func petitionEVM2LN(petitionEvent : Types.PetitionEvent, timestamp : Text) : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let transactionId = petitionEvent.proofTxId;
    let isPetitionRegistered : Bool = switch (petitionUsed.get(transactionId)) {
      case (null) { false };
      case (?true) { true };
      case (?false) { false };
    };

    if (isPetitionRegistered) {
      return "Petition already registered";
    };
    let resultTxDetails = await EVM.getTransactionDetails(transactionId, petitionEvent.sendingChain, transform);
    let txDetails = JSON.parse(resultTxDetails);

    let transactionToAddress = await utils.getValue(txDetails, "to");
    let receiverTransaction = utils.subText(transactionToAddress, 1, transactionToAddress.size() - 1);

    // let transactionData = await utils.getValue(txDetails, "to");
    let canisterAddress = await LN.getEvmAddr(derivationPath, keyName);

    let transactionData = await utils.getValue(txDetails, "input");

    let paymentRequest = petitionEvent.invoiceId;
    Debug.print("Decoding payment request sent: " #petitionEvent.invoiceId);
    let decodedPayReq = await LN.decodePayReq(petitionEvent.invoiceId, timestamp, transform);
    let payReqResponse = JSON.parse(decodedPayReq);
    let amountString = await utils.getValue(payReqResponse, "num_satoshis");
    let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
    Debug.print("Satoshis: " #amountString);
    var result : Text = "";

    // If there is no sentERC20 it is considered that he sent native coin, or if he is sending wbtc
    if (petitionEvent.sentERC == "0" or petitionEvent.wbtc == false) {
      if (receiverTransaction == "0x" #canisterAddress) {
        petitions.put(transactionId, petitionEvent);
        petitionUsed.put(transactionId, true);
        Debug.print("Petition created successfully");
        Debug.print("isWBTC: " #Bool.toText(petitionEvent.wbtc));
        Debug.print("sendingChain: " #petitionEvent.sendingChain);
        Debug.print("wantedAddress: " #petitionEvent.wantedAddress);
        Debug.print("wantedChain: " #petitionEvent.wantedChain);
        Debug.print("wantedERC20: " #petitionEvent.wantedERC20);
        Debug.print("sentERC20: " #petitionEvent.sentERC);
        petitionUsed.put(transactionId, true);
        result := "Petition created successfully";
      } else {
        Debug.print("Bad transaction");
        result := "Bad transaction";
      };
    } else {
      let decodedDataResult = await utils.decodeTransferERC20Data(transactionData);
      switch (decodedDataResult) {
        case (#ok((address, _))) {
          Debug.print("Canister Address: " #canisterAddress);
          Debug.print("ERC20 transfer data address: " #address);
          if ("0x" #canisterAddress == address) {
            // Check if receiver of ERC20 is the canister
            petitions.put(transactionId, petitionEvent);
            petitionUsed.put(transactionId, true);
            Debug.print("Petition for ERC20 transfer created successfully");
            result := "Petition for ERC20 transfer created successfully";
          } else {
            Debug.print("Bad ERC20 transaction");
            result := "Bad ERC20 transaction";
          };
        };
        case (#err(errorMsg)) {
          Debug.print("Error decoding ERC20 data: " # errorMsg);
          result := "Error decoding transaction data";
        };
      };
    };
    return result;
  };

  public shared (msg) func solvePetitionEVM2LN(
    invoiceId : Text,
    petitionTxId : Text,
    proofTxId : Text,
    signature : Text,
    destAddress : Text,
    timestamp : Text,
  ) : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let canisterAddress = await LN.getEvmAddr(derivationPath, keyName);

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let signerAddress = utils.publicKeyToAddress(publicKey);
    Debug.print(signerAddress);
    let petitionEvent = petitions.get(petitionTxId);
    var result : Text = "";
    switch (petitionEvent) {
      case (null) {
        result := "No petition event with that tx id";
      };
      case (?petitionEvent) {
        let requestHeaders = [
          { name = "Content-Type"; value = "application/json" },
          { name = "Accept"; value = "application/json" },
          { name = "chain-id"; value = petitionEvent.sendingChain },
        ];
        let transactionDetailsPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionByHash\", \"params\": [\"" # petitionTxId # "\"] }";
        let responseTransactionDetails : Text = await utils.httpRequest(?transactionDetailsPayload, "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app/interactWithNode", ?requestHeaders, "post", transform);
        let parsedTransactionDetails = JSON.parse(responseTransactionDetails);
        let txResult = await utils.getValue(parsedTransactionDetails, "result");
        let parsedTxResult = JSON.parse(txResult);
        let transactionProof = await utils.getValue(parsedTxResult, "to");
        Debug.print(transactionProof);
        let transactionAmount = await utils.getValue(parsedTxResult, "amount");
        let transactionData = await utils.getValue(parsedTxResult, "input");

        let transactionNat : Nat = switch (petitionEvent.sendingChain) {
          case ("0x1f") {
            Nat64.toNat(utils.hexStringToNat64(transactionAmount));
          };
          case (_) {
            let decodedDataResult = await utils.decodeTransferERC20Data(transactionData);
            switch (decodedDataResult) {
              case (#ok(_, decodedAmountNat)) {
                Debug.print("decodedAmountNat :" #Nat.toText(decodedAmountNat));
                decodedAmountNat;
              };
              case (#err(err)) {
                // Handle the error case here. You might want to log the error message
                // and return a default value, or propagate the error up to the caller.
                // For this example, let's just return 0.
                Debug.print(err);
                0;
              };
            };
          };
        };
        try {

          let paymentRequest = invoiceId;

          Debug.print(paymentRequest);
          // Verify if payment has been done to canister
          let decodedPayReq = await LN.decodePayReq(paymentRequest, timestamp, transform);
          let payReqResponse = JSON.parse(decodedPayReq);
          let amountString = await utils.getValue(payReqResponse, "num_satoshis");
          let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
          let payment_hash = await utils.getValue(payReqResponse, "payment_hash");
          Debug.print("Payment Hash: " #payment_hash);

          let paymentCheckResponse = await LN.checkInvoice(payment_hash, timestamp, transform);
          let parsedResponse = JSON.parse(paymentCheckResponse);
          let isSettled = await utils.getValue(parsedResponse, "settled");

          if (isSettled == falseString) {
            Debug.print("Invoice not settled, pay invoice and try again");
            return "Invoice not settled, pay invoice and try again";
          };

          Debug.print("Satoshis: " #amountString);
          Debug.print("cleanAmountString: " #cleanAmountString);
          let amountCheckedOpt : ?Nat = Nat.fromText(cleanAmountString # "0000000000");
          switch (amountCheckedOpt) {
            case (null) {
              result := "Failed to convert amountChecked to Nat. Skipping invoice.";
            };
            case (?amountChecked) {
              let reward : Nat = switch (Nat.fromText(petitionEvent.reward)) {
                case (null) { 0 };
                case (?value) { value };
              };
              // Verify if petition creator has been paid before
              let petitionCreatorPaid : Bool = switch (solvePetitionCreatorPaid.get(petitionTxId)) {
                case (null) { false };
                case (?true) { true };
                case (?false) { false };
              };

              Debug.print("Petiton creator paid before: " #Bool.toText(petitionCreatorPaid));
              if (petitionCreatorPaid == false) {
                Debug.print("Paying petition creator");
                // Release ln payment to petition creator
                let paymentResult = await LN.payInvoice(petitionEvent.invoiceId, derivationPath, keyName, timestamp, transform);
                Debug.print(paymentResult);
                let paymenttxDetails = JSON.parse(paymentResult);
                let errorField = await utils.getValue(paymenttxDetails, "error");
                let resultField = await utils.getValue(paymenttxDetails, "result");
                let statusField = await utils.getValue(JSON.parse(resultField), "status");
                let failureReason = await utils.getValue(JSON.parse(resultField), "failure_reason");

                Debug.print(statusField);
                // https://lightning.engineering/api-docs/api/lnd/router/send-payment-v2
                if (Text.contains(paymentResult, #text "SUCCEEDED")) {
                  // Save
                  solvePetitionCreatorPaid.put(petitionTxId, true);
                  Debug.print("Petition creator paid");
                } else if (Text.contains(paymentResult, #text "FAILED")) {
                  Debug.print("Payment to creator failed: " #failureReason);
                  // Error
                  result := "Payment to creator failed: " #failureReason;
                  return result;
                };

              };
              // Perform evm payment to petition solver
              let transferResponse = await EVM.createAndSendTransaction(
                petitionEvent.sendingChain,
                petitionEvent.sentERC,
                derivationPath,
                keyName,
                canisterAddress,
                destAddress,
                reward + transactionNat,
                publicKey,
                transform,
              );
              let isError = await utils.getValue(JSON.parse(transferResponse), "error");
              switch (isError) {
                case ("") {
                  let _ = petitions.remove(petitionTxId);

                  Debug.print("Petition solved");

                  result := transferResponse;
                };
                case (errorValue) {
                  Debug.print("Failed to transfer reward due to error: " # errorValue);
                  result := "Failed to transfer reward";
                };
              };
            };
          };
        } catch (e : Error.Error) {
          // paidInvoicestoLN.put(invoiceId, (true, transactionNat));
          // paidTransactions.put(transactionId, true);

          result := "Caught exception: " # Error.message(e);
        };
      };
    };
    result;
  };

  public shared (msg) func petitionEVM2EVM(petitionEvent : Types.PetitionEvent) : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let transactionId = petitionEvent.proofTxId;
    let isPetitionRegistered : Bool = switch (petitionUsed.get(transactionId)) {
      case (null) { false };
      case (?true) { true };
      case (?false) { false };
    };

    if (isPetitionRegistered) {
      return "Petition already registered";
    };
    let resultTxDetails = await EVM.getTransactionDetails(transactionId, petitionEvent.sendingChain, transform);
    let txDetails = JSON.parse(resultTxDetails);

    let transactionToAddress = await utils.getValue(txDetails, "to");
    let receiverTransaction = utils.subText(transactionToAddress, 1, transactionToAddress.size() - 1);

    // let transactionData = await utils.getValue(txDetails, "to");
    let canisterAddress = await LN.getEvmAddr(derivationPath, keyName);

    let transactionData = await utils.getValue(txDetails, "input");

    // If there is no sentERC20 it is considered that he sent native coin, or if he is sending wbtc
    if (petitionEvent.sentERC == "0" or petitionEvent.wbtc == false) {
      if (receiverTransaction == "0x" #canisterAddress) {
        petitions.put(transactionId, petitionEvent);
        petitionUsed.put(transactionId, true);
        Debug.print("Petition created successfully");
        Debug.print("isWBTC: " #Bool.toText(petitionEvent.wbtc));
        Debug.print("sendingChain: " #petitionEvent.sendingChain);
        Debug.print("wantedAddress: " #petitionEvent.wantedAddress);
        Debug.print("wantedChain: " #petitionEvent.wantedChain);
        Debug.print("wantedERC20: " #petitionEvent.wantedERC20);
        Debug.print("sentERC20: " #petitionEvent.sentERC);

        return "Petition created successfully";
      } else {
        Debug.print("Bad transaction");
        return "Bad transaction";
      };
    } else {
      let decodedDataResult = await utils.decodeTransferERC20Data(transactionData);
      switch (decodedDataResult) {
        case (#ok((address, _))) {
          Debug.print("Canister Address: " #canisterAddress);
          Debug.print("ERC20 transfer data address: " #address);
          if ("0x" #canisterAddress == address) {
            // Check if receiver of ERC20 is the canister
            petitions.put(transactionId, petitionEvent);
            petitionUsed.put(transactionId, true);
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
        let canisterAddress = await LN.getEvmAddr(derivationPath, keyName);

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
        Debug.print("Amount that needs to be sent: " #Nat.toText(transactionNat));
        let isWBTC : Bool = switch (petitionEvent.wantedChain) {
          case ("0x1f") {
            false;
          };
          case (_) {
            true;
          };
        };
        Debug.print("Validating transaction with parameters");
        Debug.print("isWBTC: " #Bool.toText(isWBTC));
        Debug.print("petitionEvent.wantedERC20: " #petitionEvent.wantedERC20);
        Debug.print("proofTxId: " #proofTxId);
        Debug.print("petitionEvent.wantedAddress: " #petitionEvent.wantedAddress);
        Debug.print("transactionNat: " #Nat.toText(transactionNat));
        Debug.print("petitionEvent.wantedChain: " #petitionEvent.wantedChain);
        Debug.print("Canister Address: " #canisterAddress);

        let isValidTransaction = await EVM.validateTransaction(
          petitionEvent.wantedERC20,
          proofTxId,
          "0x" #canisterAddress, // Expected address to be canister, after ok release payments
          transactionNat, // Expected amount
          petitionEvent.wantedChain,
          signature,
          transform,
        );
        Debug.print("Petition event transaction validation finished");
        if (isValidTransaction == false) {
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
          // Verify if petition creator has been paid before
          let petitionCreatorPaid : Bool = switch (solvePetitionCreatorPaid.get(petitionTxId)) {
            case (null) { false };
            case (?true) { true };
            case (?false) { false };
          };

          Debug.print("Petiton creator paid before: " #Bool.toText(petitionCreatorPaid));
          if (petitionCreatorPaid == false) {
            // Send transaction to petition creator
            Debug.print("Paying petition creator");
            let transferResponsePetitionCreator = await EVM.createAndSendTransaction(
              petitionEvent.wantedChain,
              petitionEvent.wantedERC20,
              derivationPath,
              keyName,
              canisterAddress,
              petitionEvent.wantedAddress,
              reward + transactionNat,
              publicKey,
              transform,
            );
            let isErrorPetitionCreator = await utils.getValue(JSON.parse(transferResponsePetitionCreator), "error");
            switch (isErrorPetitionCreator) {
              case ("") {
                solvePetitionCreatorPaid.put(petitionTxId, true);
                Debug.print("Petition creator received transfer");
              };
              case (errorValue) {
                Debug.print("Failed to transfer reward to creator due to error: " # errorValue);
                return "Failed to transfer to petition creator";
              };
            };
          };
          // Send transaction to petiton solver
          let transferResponse = await EVM.createAndSendTransaction(
            petitionEvent.sendingChain,
            petitionEvent.sentERC,
            derivationPath,
            keyName,
            canisterAddress,
            transactionSenderCleaned,
            transactionNat,
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

  public shared (msg) func swapLN2EVM(hexChainId : Text, wantedERC20 : Text, payment_hash : Text, timestamp : Text) : async Text {

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

    // Use the helper function to calculate the fee
    let feeAmount = calculateFee(amount);
    let amountAfterFee = amount - feeAmount;

    // Perform swap from Lightning Network to EVM or to Any other EVM compatible chain to another EVM
    let sendTxResponse = await EVM.swapLN2EVM(hexChainId, wantedERC20, derivationPath, keyName, amountAfterFee, utils.subText(evm_addr, 1, evm_addr.size() - 1), transform);

    let isError = await utils.getValue(JSON.parse(sendTxResponse), "error");

    // Accumulate the fee
    let currentAccumulatedFees = totalAccumulatedFeesEVM.get(hexChainId);
    let newAccumulatedFees = switch (currentAccumulatedFees) {
      case (null) { feeAmount };
      case (?existingAmount) { existingAmount + feeAmount };
    };

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
    let transactionData = await utils.getValue(parsedTxResult, "input");

    let transactionNat : Nat = switch (transferEvent.sendingChain) {
      case ("0x1f") {
        Nat64.toNat(utils.hexStringToNat64(transactionAmount));
      };
      case (_) {
        let decodedDataResult = await utils.decodeTransferERC20Data(transactionData);
        switch (decodedDataResult) {
          case (#ok(_, decodedAmountNat)) {
            Debug.print("decodedAmountNat :" #Nat.toText(decodedAmountNat));
            decodedAmountNat;
          };
          case (#err(err)) {
            // Handle the error case here. You might want to log the error message
            // and return a default value, or propagate the error up to the caller.
            // For this example, let's just return 0.
            Debug.print(err);
            0;
          };
        };
      };
    };
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
    var entries : [Types.PetitionEvent] = [];
    for ((_, value) in petitions.entries()) {
      entries := Array.append(entries, [value]);
    };
    entries;
  };

  // Add liquidity Lightning network

  public shared (msg) func addLiquidityLN(payment_hash : Text, timestamp : Text) : async Text {
    let principalId = msg.caller;
    let paymentCheckResponse = await LN.checkInvoice(payment_hash, timestamp, transform);
    let parsedResponse = JSON.parse(paymentCheckResponse);
    let isSettled = await utils.getValue(parsedResponse, "settled");
    let amountSatoshi = await utils.getValue(parsedResponse, "value");
    let memo = await utils.getValue(parsedResponse, "memo");
    let amount : Nat = switch (Nat.fromText(utils.subText(amountSatoshi, 1, amountSatoshi.size() - 1) # "0000000000")) {
      case (null) { 0 };
      case (?value) { value };
    };
    if (isSettled == falseString) {
      return "Invoice not settled, pay invoice and try again";
    };
    if (memo != Principal.toText(principalId)) {
      return "Invoice memo does not match your principal";
    };
    // Update totalLiquidityLN and liquidityProvidersLN
    totalLiquidityLN := totalLiquidityLN + amount;
    let currentLiquidity = liquidityProvidersLN.get(Principal.toText(principalId));
    let newLiquidity = switch (currentLiquidity) {
      case (null) { amount };
      case (?existingAmount) { existingAmount + amount };
    };
    liquidityProvidersLN.put(Principal.toText(principalId), newLiquidity);
    return "Liquidity added successfully";
  };

  public shared (msg) func addLiquidityEVM(txHash : Text, chainId : Text) : async Text {
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    let evmAddress = await LN.getEvmAddr(derivationPath, keyName);

    Debug.print("evmAddress" #evmAddress);

    // Verify transaction
    let resultTxDetails = await EVM.getTransactionDetails(txHash, chainId, transform);
    let txDetails = JSON.parse(resultTxDetails);

    let transactionToAddress = await utils.getValue(txDetails, "to");
    let receiverTransaction = utils.subText(transactionToAddress, 1, transactionToAddress.size() - 1);
    let transactionAmount = await utils.getValue(txDetails, "value");
    let transactionAmountNat64 = utils.hexStringToNat64(transactionAmount);
    let amount = Nat64.toNat(transactionAmountNat64);

    if (receiverTransaction != "0x" #evmAddress) {
      return "Transaction receiver does not match the canister address";
    };

    // Update totalLiquidityEVM for the specified chain
    let currentTotalLiquidity = totalLiquidityEVM.get(chainId);
    let newTotalLiquidity = switch (currentTotalLiquidity) {
      case (null) { amount };
      case (?existingAmount) { existingAmount + amount };
    };
    totalLiquidityEVM.put(chainId, newTotalLiquidity);

    // Update liquidityProvidersEVM for the specified chain
    let chainProviders = switch (liquidityProvidersEVM.get(chainId)) {
      case (null) {
        let newMap = HashMap.HashMap<PrincipalIdText, Nat>(10, Text.equal, Text.hash);
        liquidityProvidersEVM.put(chainId, newMap);
        newMap;
      };
      case (?existingMap) { existingMap };
    };

    let currentLiquidity = chainProviders.get(Principal.toText(principalId));
    let newLiquidity = switch (currentLiquidity) {
      case (null) { amount };
      case (?existingAmount) { existingAmount + amount };
    };
    chainProviders.put(Principal.toText(principalId), newLiquidity);

    return "Liquidity added successfully to chain " # chainId;
  };

  //Withdraw fee LN TODO:

  // public shared func withdrawFeesLN(providerId : Text, destinationPaymentRequest : Text, timestamp : Text) : async Text {

  //   // No need to get the principal ID
  //   // let principalId = msg.caller;

  //   // No need to derive the derivation path from the principal ID
  //   // let derivationPath = [Principal.toBlob(principalId)];

  //   // Retrieve the provider's accumulated fees

  //   let accumulatedFeesOpt = providerFeesLN.get(providerId);
  //   let accumulatedFees : Nat = switch (accumulatedFeesOpt) {
  //     case (null) { 0 };
  //     case (?amount) { amount };
  //   };

  //   // Retrieve the provider's liquidity amount
  //   let providerLiquidityOpt = liquidityProvidersLN.get(providerId);
  //   let providerLiquidity : Nat = switch (providerLiquidityOpt) {
  //     case (null) { 0 };
  //     case (?amount) { amount };
  //   };

  //   // Total amount available to withdraw
  //   let totalAmount : Nat = accumulatedFees + providerLiquidity;

  //   if (totalAmount == 0) {
  //     return "No fees or liquidity to withdraw";
  //   };

  //   // Decode the payment request to get the invoice amount
  //   let paymentRequest = utils.trim(destinationPaymentRequest);
  //   Debug.print("Payment Request: " # paymentRequest);
  //   let decodedPayReq = await LN.decodePayReq(paymentRequest, timestamp, transform);
  //   let payReqResponse = JSON.parse(decodedPayReq);

  //   // Extract the amount in satoshis
  //   let amountStringOpt = await utils.getValue(payReqResponse, "num_satoshis");
  //   let amountString = switch (amountStringOpt) {
  //     case (null) { return "Failed to retrieve invoice amount" };
  //     case (?value) { value };
  //   };
  //   let cleanAmountString = utils.subText(amountString, 1, amountString.size() - 1);
  //   Debug.print("Invoice Amount (satoshis): " # cleanAmountString);

  //   // Convert the amount to Nat (satoshis)
  //   let invoiceAmountOpt : ?Nat = Nat.fromText(cleanAmountString # "0000000000"); // Multiply by 10^10 to match units
  //   let invoiceAmount = switch (invoiceAmountOpt) {
  //     case (null) { return "Failed to parse invoice amount" };
  //     case (?value) { value };
  //   };

  //   // Check if the invoice amount exceeds the total amount available
  //   if (invoiceAmount > totalAmount) {
  //     return "Invoice amount exceeds the total amount available to withdraw";
  //   };

  //   // Proceed to pay the invoice
  //   // Since we don't have the principal ID, we'll use a default derivation path and key
  //   let derivationPath = []; // Empty derivation path for canister's default key
  //   let keyName = "canister_key"; // Replace with your actual key name

  //   let paymentResult = await LN.payInvoice(paymentRequest, derivationPath, keyName, timestamp, transform);
  //   Debug.print("Payment Result: " # paymentResult);
  //   let paymenttxDetails = JSON.parse(paymentResult);

  //   // Extract the payment status
  //   let statusFieldOpt = await utils.getValue(paymenttxDetails, "status");
  //   let statusField = switch (statusFieldOpt) {
  //     case (null) { return "Failed to retrieve payment status" };
  //     case (?jsonValue) {
  //       switch (jsonValue) {
  //         case (JSON.Text(statusText)) { statusText };
  //         case (_) { return "Payment status is not a text value" };
  //       };
  //     };
  //   };

  //   // Check if the payment was successful
  //   if (Text.contains(statusField, #text "SUCCEEDED")) {
  //     // Deduct the invoice amount from the provider's accumulated fees and liquidity
  //     var remainingAmount = invoiceAmount;
  //     var feesToDeduct = 0;
  //     var liquidityToDeduct = 0;

  //     if (accumulatedFees >= remainingAmount) {
  //       feesToDeduct := remainingAmount;
  //       remainingAmount := 0;
  //     } else {
  //       feesToDeduct := accumulatedFees;
  //       remainingAmount := remainingAmount - accumulatedFees;
  //     };

  //     if (remainingAmount > 0) {
  //       // Deduct the rest from the provider's liquidity
  //       if (providerLiquidity >= remainingAmount) {
  //         liquidityToDeduct := remainingAmount;
  //         remainingAmount := 0;
  //       } else {
  //         liquidityToDeduct := providerLiquidity;
  //         remainingAmount := remainingAmount - providerLiquidity;
  //       };
  //     };

  //     // Update the provider's accumulated fees and liquidity
  //     if (feesToDeduct == accumulatedFees) {
  //       providerFeesLN.remove(providerId);
  //     } else {
  //       providerFeesLN.put(providerId, accumulatedFees - feesToDeduct);
  //     };

  //     if (liquidityToDeduct == providerLiquidity) {
  //       liquidityProvidersLN.remove(providerId);
  //     } else {
  //       liquidityProvidersLN.put(providerId, providerLiquidity - liquidityToDeduct);
  //     };

  //     // Update total liquidity and accumulated fees
  //     totalAccumulatedFeesLN := totalAccumulatedFeesLN - feesToDeduct;
  //     totalLiquidityLN := totalLiquidityLN - liquidityToDeduct;

  //     return "Fees and liquidity withdrawn successfully";
  //   } else {
  //     return "Failed to withdraw fees and liquidity";
  //   };
  // };

  public shared (msg) func withdrawFeesEVM(destinationAddress : Text, chainId : Text) : async Text {

    let principalId = msg.caller;

    let derivationPath = [Principal.toBlob(principalId)];
    // Logging
    Debug.print("withdrawFeesEVM called with:");
    Debug.print("  destinationAddress: " # destinationAddress);
    Debug.print("  chainId: " # chainId);
    Debug.print("  principalId: " # Principal.toText(principalId));

    // Get total accumulated fees for the chain
    let totalFeesOpt = totalAccumulatedFeesEVM.get(chainId);
    let totalFees = switch (totalFeesOpt) {
      case (null) {
        return "No fees accumulated for chain " # chainId;
      };
      case (?fees) { fees };
    };

    Debug.print("Total accumulated fees for chain " # chainId # ": " # Nat.toText(totalFees));

    // Get total liquidity for the chain
    let totalLiquidityOpt = totalLiquidityEVM.get(chainId);
    let totalLiquidity = switch (totalLiquidityOpt) {
      case (null) {
        return "No liquidity provided for chain " # chainId;
      };
      case (?liq) { liq };
    };

    Debug.print("Total liquidity for chain " # chainId # ": " # Nat.toText(totalLiquidity));

    if (totalLiquidity == 0) {
      return "Total liquidity for chain " # chainId # " is zero. Cannot compute fees.";
    };

    // Get user's liquidity for the chain
    let chainLiquidityProvidersOpt = liquidityProvidersEVM.get(chainId);
    let chainLiquidityProviders = switch (chainLiquidityProvidersOpt) {
      case (null) {
        return "No liquidity providers for chain " # chainId;
      };
      case (?providers) { providers };
    };

    let userLiquidityOpt = chainLiquidityProviders.get(Principal.toText(principalId));
    let userLiquidity = switch (userLiquidityOpt) {
      case (null) {
        return "You have not provided liquidity for chain " # chainId;
      };
      case (?liq) { liq };
    };

    Debug.print("User's liquidity for chain " # chainId # ": " # Nat.toText(userLiquidity));

    // Get user's last accumulated fees for the chain
    let chainUserLastFeesOpt = userLastAccumulatedFeesEVM.get(chainId);
    let chainUserLastFees = switch (chainUserLastFeesOpt) {
      case (null) {
        // Initialize empty map for this chain
        let newMap = HashMap.HashMap<PrincipalIdText, Nat>(10, Text.equal, Text.hash);
        userLastAccumulatedFeesEVM.put(chainId, newMap);
        newMap;
      };
      case (?map) { map };
    };

    let userLastAccumulatedFeesOpt = chainUserLastFees.get(destinationAddress);
    let userLastAccumulatedFees = switch (userLastAccumulatedFeesOpt) {
      case (null) { 0 };
      case (?fees) { fees };
    };

    Debug.print("User's last accumulated fees for chain " # chainId # ": " # Nat.toText(userLastAccumulatedFees));

    // Compute deltaFees
    let deltaFees = Nat.sub(totalFees, userLastAccumulatedFees);

    if (deltaFees == 0) {
      return "No new fees to withdraw";
    };

    Debug.print("Delta fees since last withdrawal: " # Nat.toText(deltaFees));

    // Compute user's share
    let userShare = (userLiquidity * deltaFees) / totalLiquidity;

    Debug.print("Computed userShare: " # Nat.toText(userShare));

    if (userShare == 0) {
      return "No fees to withdraw";
    };


    let canisterAddress = await LN.getEvmAddr(derivationPath, keyName);
    Debug.print("Canister EVM Address: " # canisterAddress);

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    // Create and send transaction to transfer fees to provider
    Debug.print("Creating and sending transaction with the following parameters:");
    Debug.print("  chainId: " # chainId);
    Debug.print("  erc20: 0"); // Assuming native coin
    Debug.print("  keyName: " # keyName);
    Debug.print("  canisterAddress: " # canisterAddress);
    Debug.print("  destinationAddress: " # destinationAddress);
    Debug.print("  amount: " # Nat.toText(userShare));

    let transferResponse = await EVM.createAndSendTransaction(
      chainId,
      "0", // Assuming native coin
      derivationPath,
      keyName,
      canisterAddress,
      destinationAddress,
      userShare,
      publicKey,
      transform,
    );

    Debug.print("Transfer Response: " # transferResponse);

    // Parse the transfer response
    let transferResponseJson = JSON.parse(transferResponse);

    // Get the 'error' field from the response
    let isError = await utils.getValue(transferResponseJson, "error");
    Debug.print("isError: " # isError);

    if (isError == "") {
      // Success case
      // Update user's last accumulated fees
      chainUserLastFees.put(Principal.toText(principalId), totalFees);

      return "Fees withdrawn successfully";
    } else {
      // Error case
      return "Failed to withdraw fees due to error: " # isError;
    };
  };

};
