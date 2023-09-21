import RSK_testnet_mo "./rsk_testnet";
import Principal "mo:base/Principal";



actor {


public shared(msg) func swapFromLightningNetwork(address: Text):  async Text{
  
    let keyName = "dfx_test_key";
    let principalId = msg.caller;
    let derivationPath = [Principal.toBlob(principalId)];

    await RSK_testnet_mo.swapFromLightningNetwork(derivationPath,keyName, address );

    return "";

}  ;

















}