import { useCallback,useMemo, useState,useEffect } from "react";
import { ethers } from "ethers";
import Web3Modal from "web3modal";


const web3Modal = new Web3Modal({
  cacheProvider: true
});

function useWeb3Modal(config = {}) {
  const rskNodeUrl = "https://rsk.getblock.io/437f13d7-2175-4d2c-a8c4-5e45ef6f7162/testnet/";

  const [provider, setProvider] = useState(new ethers.JsonRpcProvider(rskNodeUrl));
  const [coinbase, setCoinbase] = useState();
  const [netId , setNetId] = useState(31);
  const [connecting , setConnecting] = useState();
  const [noProvider , setNoProvider] = useState();

  //const [cyberConnect , setCyberConnect] = useState();

  const [autoLoaded, setAutoLoaded] = useState(false);
  // Web3Modal also supports many other wallets.
  // You can see other options at https://github.com/Web3Modal/web3modal
  const logoutOfWeb3Modal = useCallback(
    async function () {
      await web3Modal.clearCachedProvider();
      setCoinbase();
      setNetId(31);
      setProvider(new ethers.JsonRpcProvider(rskNodeUrl));
    },
    [],
  );
  // Open wallet selection modal.
  const loadWeb3Modal = useCallback(async () => {

    try{
      setConnecting(true)
      setAutoLoaded(true);
      const conn = await web3Modal.connect();
      const newProvider = new ethers.BrowserProvider(conn,"any");
      const signer = await newProvider.getSigner()
      const newCoinbase = await signer.getAddress();
      const {chainId} = await newProvider.getNetwork();
      setProvider(newProvider);
      setCoinbase(newCoinbase);
      setNetId(chainId);
      setNoProvider(true);
      setConnecting(false);

      conn.on('accountsChanged', accounts => {
        const newProvider = new ethers.BrowserProvider(conn,"any");
        setProvider(newProvider)
        setCoinbase(accounts[0]);
      });
      conn.on('chainChanged', async chainId => {
        window.location.reload();
      });
      // Subscribe to provider disconnection
      conn.on("disconnect", async (error) => {
        logoutOfWeb3Modal();
      });
      conn.on("close", async () => {
        logoutOfWeb3Modal();
      });

      return;
    } catch(err){
      console.log(err);
      setConnecting(false)
      logoutOfWeb3Modal();
    }

  }, [logoutOfWeb3Modal]);




  // If autoLoad is enabled and the the wallet had been loaded before, load it automatically now.
  useMemo(() => {
    if (!autoLoaded && web3Modal.cachedProvider) {
      setAutoLoaded(true);
      loadWeb3Modal();
      setNoProvider(true);
    }
  },[autoLoaded,loadWeb3Modal]);
  useMemo(() => {

    if(!noProvider && !autoLoaded && !web3Modal.cachedProvider && !connecting){
      setProvider(new ethers.JsonRpcProvider(rskNodeUrl));
      setNetId(31);
      setNoProvider(true);
      setAutoLoaded(true);
    }



  },[
    noProvider,
    autoLoaded,
    connecting
   ]);


  return({provider, loadWeb3Modal, logoutOfWeb3Modal,coinbase,netId,connecting});
}



export default useWeb3Modal;
