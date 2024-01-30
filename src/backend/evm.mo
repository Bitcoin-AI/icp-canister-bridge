import Types "Types";
import Debug "mo:base-0.7.3/Debug";
import Blob "mo:base-0.7.3/Blob";
import Cycles "mo:base-0.7.3/ExperimentalCycles";
import Error "mo:base-0.7.3/Error";
import Array "mo:base-0.7.3/Array";
import Nat8 "mo:base-0.7.3/Nat8";
import Nat64 "mo:base-0.7.3/Nat64";
import Text "mo:base-0.7.3/Text";
import Nat "mo:base-0.7.3/Nat";
import Int "mo:base-0.7.3/Int";
import List "mo:base-0.7.3/List";
import Iter "mo:base-0.7.3/Iter";
import Char "mo:base-0.7.3/Char";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import JSON "mo:json/JSON";
import Buffer "mo:base-0.7.3/Buffer";
import Helper "mo:evm-tx/transactions/Helper";
import AU "mo:evm-tx/utils/ArrayUtils";
import TU "mo:evm-tx/utils/TextUtils";
import HU "mo:evm-tx/utils/HashUtils";
import Context "mo:evm-tx/Context";
import Address "mo:evm-tx/Address";

import IcEcdsaApi "mo:evm-tx/utils/IcEcdsaApi";
import RLP "mo:rlp/hex/lib";
import Legacy "mo:evm-tx/transactions/Legacy";
import Transaction "mo:evm-tx/Transaction";
import PublicKey "mo:libsecp256k1/PublicKey";
import Signature "mo:libsecp256k1/Signature";
import utils "utils";

module {

  let API_URL : Text = "https://icp-macaroon-bridge-cdppi36oeq-uc.a.run.app";

  type JSONField = (Text, JSON.JSON);

  public func validateTransaction(transactionId : Text, expectedCanisterAddress : Text, expectedAmount : Nat, signature : Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Bool {
    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
    ];

    // Fetch TransactionDetails
    let resultTxDetails = await getTransactionDetails(transactionId, transform);
    let txDetails = JSON.parse(resultTxDetails);

    let transactionToAddress = await utils.getValue(txDetails, "to");
    let receiverTransaction = utils.subText(transactionToAddress, 1, transactionToAddress.size() - 1);

    let transactionAmount = await utils.getValue(txDetails, "value");
    let transactionNat = Nat64.toNat(utils.hexStringToNat64(transactionAmount));

    // Check if the recipient address and amount in the transaction match the expected values
    if ("0x" # receiverTransaction == expectedCanisterAddress and transactionNat == expectedAmount) {
      // Optionally check the signature if required
      // let validSignature = await checkSignature(transactionId, transactionSender, signature);
      // return validSignature;
      return true;
    } else {
      return false;
    };
  };

  public func getTransactionDetails(transactionHash : Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {

    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
    ];

    let transactionDetailsPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionByHash\", \"params\": [\"" # transactionHash # "\"] }";
    let responseTransactionDetails : Text = await utils.httpRequest(?transactionDetailsPayload, API_URL # "/interactWithNode", ?requestHeaders, "post", transform);
    let parsedTransactionDetails = JSON.parse(responseTransactionDetails);

    return await utils.getValue(parsedTransactionDetails, "result");

  };

  public func swapEVM2EVM(transferEvent : Types.TransferEvent, derivationPath : [Blob], keyName : Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {

    let recipientAddr = transferEvent.recipientAddress;
    let recipientChainId = transferEvent.recipientChain;
    let sendingChainId = transferEvent.sendingChain;
    let transactionId = transferEvent.proofTxId;

    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let canisterAddress = utils.publicKeyToAddress(publicKey);

    Debug.print("Recipient address: 0x" # recipientAddr);
    Debug.print("recipientChainId" # recipientChainId);
    Debug.print("sendingChainId" # sendingChainId);

    if (canisterAddress == "") {
      Debug.print("Could not get address!");
      return "";
    } else {
      Debug.print("Canister Address: 0x" # canisterAddress);
    };

    //We will check the transactionId on the sendingChain to see if he sent any money

    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "chain-id"; value = transferEvent.sendingChain },
    ];

    // Fetch transaction details using transactionId
    let resultTxDetails = await getTransactionDetails(transactionId, transform);
    let txDetails = JSON.parse(resultTxDetails);

    let transactionProof = await utils.getValue(txDetails, "to");
    let receiverTransaction = utils.subText(transactionProof, 1, transactionProof.size() - 1);

    Debug.print("TO " # receiverTransaction);

    let transactionSender = await utils.getValue(txDetails, "from");
    let transactionSenderCleaned = utils.subText(transactionSender, 1, transactionSender.size() - 1);

    Debug.print("transactionFrom   " # transactionSenderCleaned);

    let transactionAmount = await utils.getValue(txDetails, "value");
    Debug.print("transactionAmount  " # transactionAmount);

    let transactionNat = Nat64.toNat(utils.hexStringToNat64(transactionAmount));

    // Check signature, signer = transaction sender

    let validSignature = await checkSignature(transactionId, transactionSenderCleaned, transferEvent.signature);
    // Check if the recipient address and amount in the transaction match your criteria
    if (receiverTransaction == "0x" #canisterAddress and validSignature) {
      return await createAndSendTransaction(
        recipientChainId,
        derivationPath,
        keyName,
        canisterAddress,
        recipientAddr,
        transactionNat,
        publicKey,
        transform,
      );
    } else {
      Debug.print("Transaction does not match the criteria");
      throw Error.reject("Error: Not valid transaction");
    };

  };

  public func swapLN2EVM(hexChainId : Text, derivationPath : [Blob], keyName : Text, amount : Nat, recipientAddr : Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {
    let publicKey = Blob.toArray(await* IcEcdsaApi.create(keyName, derivationPath));

    let canisterAddress = utils.publicKeyToAddress(publicKey);

    return await createAndSendTransaction(
      hexChainId,
      derivationPath,
      keyName,
      canisterAddress,
      recipientAddr,
      amount,
      publicKey,
      transform,
    );

  };

  public func checkSignature(transactionId : Text, from : Text, signature : Text) : async Bool {

    let ecCtx = Context.allocECMultContext(null);

    let prefixBytes : [Nat8] = [
      0x19,
      0x45,
      0x74,
      0x68,
      0x65,
      0x72,
      0x65,
      0x75,
      0x6d,
      0x20, // "\x19Ethereum "
      0x53,
      0x69,
      0x67,
      0x6e,
      0x65,
      0x64,
      0x20,
      0x4d,
      0x65,
      0x73, // "Signed Mes"
      0x73,
      0x61,
      0x67,
      0x65,
      0x3a,
      0x0a // "sage:\n"
    ];

    let messageLength = Text.size(transactionId);
    let messageLengthBytes = TU.encodeUtf8(Nat.toText(messageLength));

    let messageBytes = TU.encodeUtf8(transactionId);

    let fullMessageBytes = Array.append(prefixBytes, Array.append(messageLengthBytes, messageBytes));

    let keccak256_hex = HU.keccak(fullMessageBytes, 256);

    let signatureLength = Text.size(signature);
    let v = utils.subText(signature, signatureLength - 2, signatureLength);

    let recoveryId = await utils.hexToNat(v);

    let signatureParsed = Signature.parse_standard(AU.fromText(signature));

    Debug.print("recoveryId: " # Nat.toText(recoveryId -27));

    let messageHashHex = AU.toText(keccak256_hex);

    Debug.print("Message: " # messageHashHex);

    switch (signatureParsed) {
      case (#err(msg)) {
        return false;
      };
      case (#ok(signature)) {
        let serializedSignature = signature.serialize();

        Debug.print("signature Debug:" #AU.toText(serializedSignature));

        let senderPublicKeyResult = Address.recover(
          serializedSignature,
          Nat8.fromNat(recoveryId -27),
          keccak256_hex,
          ecCtx,
        );

        switch (senderPublicKeyResult) {
          case (#ok(publicKey)) {

            Debug.print("signer  " # publicKey);

            if (publicKey == from) {
              Debug.print("Correct signature");
              return true;

            } else {
              Debug.print("Signature is not correct");
              return false;
            };

          };
          case (#err(errorMsg)) {
            Debug.print("errorMsg" # errorMsg);
            throw Error.reject("Error: Not valid transaction");

          };
        };
      };
    };

  };

  private func checkEIP11559(chainId : Text, transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Bool {

    let gasPricePayload = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_gasPrice\", \"params\": [] }";

    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "chain-id"; value = chainId },
    ];

    // Check for baseFeePerGas in the latest block
    let blockPayload = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getBlockByNumber\", \"params\": [\"latest\", false] }";
    let responseGasPrice : Text = await utils.httpRequest(?blockPayload, API_URL # "/interactWithNode", ?requestHeaders, "post", transform);
    let parsedBlock = JSON.parse(responseGasPrice);

    // Check if 'baseFeePerGas' field is present
    let baseFeePerGas = await utils.getValue(parsedBlock, "baseFeePerGas");

    switch (baseFeePerGas) {
      case ("") {
        Debug.print("baseFeePerGas not found Not EIP1159");
        return false;
      };
      case (baseFeePerGas) {
        Debug.print("baseFeePerGas found EIP1159");
        return true;
      };
    };
  };

  public func createAndSendTransaction(hexChainId : Text, derivationPath : [Blob], keyName : Text, canisterAddress : Text, recipientAddr : Text, transactionAmount : Nat, publicKey : [Nat8], transform : shared query Types.TransformArgs -> async Types.CanisterHttpResponsePayload) : async Text {
    // here check the transactionId, if he sent the money to our canister Address, save the amount

    // Now transactionAmount is a Nat and can be used in further calculations

    // This will be now a transaction without data

    // let method_sig = "swapFromLightningNetwork(address,uint256)";
    // let keccak256_hex = AU.toText(HU.keccak(TU.encodeUtf8(method_sig), 256));
    // let method_id = TU.left(keccak256_hex, 7);
    // let address_64 = TU.fill(address, '0', 64);
    // let amount_hex = AU.toText(AU.fromNat256(amount));
    // let amount_64 = TU.fill(amount_hex, '0', 64);

    // let data = "0x" # method_id # address_64 # amount_64;

    let varEIP1159 = await checkEIP11559(recipientAddr, transform);

    // if true .. etc

    let requestHeaders = [
      { name = "Content-Type"; value = "application/json" },
      { name = "Accept"; value = "application/json" },
      { name = "chain-id"; value = hexChainId },
    ];

    // Fetching maxPriorityFeePerGas for EIP-1559 transactions
    let maxPriorityFeePerGas = if (varEIP1159) {
      let priorityFeePayload = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_maxPriorityFeePerGas\", \"params\": [] }";

      let responsePriorityFee = await utils.httpRequest(?priorityFeePayload, API_URL # "/interactWithNode", ?requestHeaders, "post", transform);
      Debug.print("responsePriorityFee" # responsePriorityFee);

      let parsedPriorityFee = JSON.parse(responsePriorityFee);
      await utils.getValue(parsedPriorityFee, "result");
    } else {
      "0x0"; // Default value for non-EIP-1559 chains
    };

    Debug.print("maxPriorityFeePerGas" # maxPriorityFeePerGas);

    let gasPricePayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_gasPrice\", \"params\": [] }";
    let responseGasPrice : Text = await utils.httpRequest(?gasPricePayload, API_URL # "/interactWithNode", ?requestHeaders, "post", transform);

    let parsedGasPrice = JSON.parse(responseGasPrice);

    let gasPrice = await utils.getValue(parsedGasPrice, "result");

    Debug.print("gasPrice" # gasPrice);

    let estimateGasPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_estimateGas\", \"params\": [{ \"to\": \"" # recipientAddr # "\", \"value\": \"0x1\", \"data\": \"0x00\" }] }";
    let responseGas : Text = await utils.httpRequest(?estimateGasPayload, API_URL # "/interactWithNode", ?requestHeaders, "post", transform);
    Debug.print("responseGas" # responseGas);

    let parsedGasValue = JSON.parse(responseGas);
    let gas = await utils.getValue(parsedGasValue, "result");

    Debug.print("gas" # gas);

    let noncePayLoad : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_getTransactionCount\", \"params\": [\"0x" # canisterAddress # "\", \"latest\"] }";
    let responseNoncepayLoad : Text = await utils.httpRequest(?noncePayLoad, API_URL # "/interactWithNode", ?requestHeaders, "post", transform);

    Debug.print("responseNoncepayLoad" # responseNoncepayLoad);

    let parsedNonce = JSON.parse(responseNoncepayLoad);
    let nonce = await utils.getValue(parsedNonce, "result");

    Debug.print("nonce" # nonce);

    let chainId = utils.hexStringToNat64(hexChainId);

    let emptyAccessList : [(Text, [Text])] = [];

    // Transaction details
    let transactionEIP1559 = {
      nonce = utils.hexStringToNat64(nonce);
      maxPriorityFeePerGas = utils.hexStringToNat64(maxPriorityFeePerGas);
      maxFeePerGas = utils.hexStringToNat64(gasPrice);
      gasLimit = utils.hexStringToNat64(gas);
      to = recipientAddr;
      value = transactionAmount;
      data = "0x00";
      chainId = chainId;
      v = "0x00";
      r = "0x00";
      s = "0x00";
      accessList = emptyAccessList;

    };

    let transactionLegacy = {
      nonce = utils.hexStringToNat64(nonce);
      gasPrice = utils.hexStringToNat64(gasPrice);
      gasLimit = utils.hexStringToNat64(gas);
      to = recipientAddr;
      value = transactionAmount;
      data = "0x00";
      chainId = chainId;
      v = "0x00";
      r = "0x00";
      s = "0x00";
    };
    let ecCtx = Context.allocECMultContext(null);

    let serializedTx = await* (
      if (varEIP1159) {
        Transaction.signTx(
          #EIP1559(?transactionEIP1559),
          chainId,
          keyName,
          derivationPath,
          publicKey,
          ecCtx,
          { create = IcEcdsaApi.create; sign = IcEcdsaApi.sign },
        );
      } else {
        Transaction.signTx(
          #Legacy(?transactionLegacy),
          chainId,
          keyName,
          derivationPath,
          publicKey,
          ecCtx,
          { create = IcEcdsaApi.create; sign = IcEcdsaApi.sign },
        );
      }
    );

    switch (serializedTx) {
      case (#ok value) {
        let requestHeaders = [
          { name = "Content-Type"; value = "application/json" },
          { name = "Accept"; value = "application/json" },
          { name = "Idempotency-Key"; value = AU.toText(value.1) },
          { name = "chain-id"; value = hexChainId },
        ];
        Debug.print("serializedTx: " # AU.toText(value.1));

        let sendTxPayload : Text = "{ \"jsonrpc\": \"2.0\", \"id\": 1, \"method\": \"eth_sendRawTransaction\", \"params\": [\"0x" # AU.toText(value.1) # "\"] }";
        Debug.print("Sending tx: " # sendTxPayload);

        let request_body_json : Text = sendTxPayload;
        Debug.print("Body " #request_body_json);

        let sendTxResponse : Text = await utils.httpRequest(?request_body_json, API_URL # "/payBlockchainTx", ?requestHeaders, "post", transform);
        Debug.print("Tx response: " # sendTxResponse);
        return sendTxResponse;

      };
      case (#err errMsg) {
        Debug.print("Error: " # errMsg);
        return errMsg;
      };
    };

  };

};
