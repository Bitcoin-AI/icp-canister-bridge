import RSK_testnet_mo "./rsk_testnet";
import lightning_testnet "./lightning_testnet";
import utils "utils";

import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import JSON "mo:json/JSON";
import Text "mo:base-0.7.3/Text";



actor {

type JSONField = (Text, JSON.JSON);

 type Event = {
  address : Text;
 };

 let paidInvoices = HashMap.HashMap<Text, Bool>(10, Text.equal, Text.hash);

// From Lightning network to RSK blockchain

public func generateInvoiceToSwapToRsk(amount: Nat,address: Text): async Text {
  let invoiceResponse = await lightning_testnet.generateInvoice(amount,address);
  return invoiceResponse;
};
public shared(msg) func swapFromLightningNetwork(payment_hash: Text):  async Text{

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];
    // Check if invoice has been payed;
    let paymentCheckResponse = await lightning_testnet.checkInvoice(payment_hash);
    let parsedResponse = JSON.parse(paymentCheckResponse);
    // Check if payment is settled and get evm_address)
    let result = await utils.getValue(parsedResponse,"result");
    let evm_addr = await utils.getValue(JSON.parse(result),"memo");
    let isSettled = await utils.getValue(JSON.parse(result),"settled");
    let invoice = await utils.getValue(JSON.parse(result),"payment_request");

    if(isSettled == "false"){
      return "Invoice not settled, pay invoice and try again";
    };

    let isPaid = paidInvoices.get(invoice);



    let isPaidBoolean : Bool =
      switch(isPaid) {
        case (null) { false };
        case (?true) { true };
        case (?false) { false };
      };

    if(isPaidBoolean){
      return "Invoice is already paid and rsk transaction processed";
    };


    // Perform swap from Lightning Network to Ethereum
    let sendTxResponse = await RSK_testnet_mo.swapFromLightningNetwork(derivationPath,keyName, evm_addr );
    // Invoice not found, mark it as paid in the paidInvoices map
    paidInvoices.put(invoice, true);
    return sendTxResponse;


} ;

public shared(msg) func getEvmAddr(): async Text {
  let keyName = "dfx_test_key";
  let principalId = msg.caller;
  let derivationPath = [Principal.toBlob(principalId)];
  let address = await lightning_testnet.getEvmAddr(derivationPath,keyName);
  return address;
};

//From RSK Blockchain to LightningNetwork
public shared(msg) func payInvoicesAccordingToEvents() : async [Event]{

    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    await RSK_testnet_mo.readRSKSmartContractEvents();


    /// lista de eventos = await RSK_testnet_mo.readRSKSmartContractEvents();  [invociesId, status]


    // for a ALBY_testnet.payInvoices (derivationPath, keyName, invoiceId )
    // await lightning_testnet.payInvoice(INVOICE,derivationPath,keyName);

    // response
};

















}
