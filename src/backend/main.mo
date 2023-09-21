import RSK_testnet_mo "./rsk_testnet";
import Principal "mo:base/Principal";



actor {


  type Event = {
    address : Text;
  };


// From Lightning network to RSK blockchain
public shared(msg) func swapFromLightningNetwork(address: Text):  async Text{
  
    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    await RSK_testnet_mo.swapFromLightningNetwork(derivationPath,keyName, address );


}  ;



//From RSK Blockchain to LightningNetwork
public shared(msg) func payInvoicesAccordingToEvents() : async [Event]{


    await RSK_testnet_mo.readRSKSmartContractEvents();

 
    /// lista de eventos = await RSK_testnet_mo.readRSKSmartContractEvents();  [invociesId, status]


    // for a ALBY_testnet.payInvoices (derivationPath, keyName, invoiceId )
    // 

    // response 
}

















}