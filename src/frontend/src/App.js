import React, { useState, useEffect } from "react";
import { main } from "../../declarations/main";
import useWeb3Modal from "./hooks/useWeb3Modal";
import styles from './RSKLightningBridge.module.css';  // Import the CSS module

import EvmToLightning from "./pages/evmToLightning";
import EvmToEvm from "./pages/evmToEvm";
import LightningToEvm from "./pages/lightningToEvm";
import NostrEvents from "./pages/nostrEvents";


const App = () => {
  // State hooks
  const [activeTab, setActiveTab] = useState('rskToLight');
  const [rskBalance, setUserBalance] = useState();

  const [nodeInfo,setNodeInfo] = useState();

  const [chains,setChains] = useState([]);

  const [canisterAddr,setCanisterAddr] = useState();

  const {
    netId,
    coinbase,
    provider,
    loadWeb3Modal
  } = useWeb3Modal();


  useEffect(() => {
    let rpcNodes = [];
    fetch("https://chainid.network/chains.json").then(async response => {
      const chainsResp = await response.json();
      chainsResp.map(item => {
        const rpc = item.rpc.filter(rpc => {
          if(rpc.indexOf("INFURA_API_KEY") !== -1 || rpc.indexOf("rsk") !== -1 || rpc.indexOf("mumbai") !== -1){
            console.log(rpc)
            return(rpc)
          }
        });
        if(rpc.length > 0){
          console.log(item)
          rpcNodes.push(item)
        }
      });
      setChains(rpcNodes);
    });
  }, []);


  useEffect(() => {
    if (coinbase) {
      setEvmAddr(coinbase);
    }
  }, [coinbase]);

  /*
  const fetchUserBalance = useCallback(async () => {
    if (coinbase && bridge) {
      try {
        const balance = await bridge.userBalances(coinbase);
        setUserBalance(balance.toString());
      } catch (error) {
        console.error("Error fetching user balance:", error);
      }
    }
  }, [coinbase, bridge]);

  useEffect(() => {
    fetchUserBalance(); // Fetch balance immediately when component mounts or coinbase/bridge changes

    const intervalId = setInterval(fetchUserBalance, 30000); // Fetch balance every 30 seconds


    return () => clearInterval(intervalId); // Clear interval on component unmount
  }, [fetchUserBalance]);
  */

  useEffect(() => {
    main.getEvmAddr().then(addr => {
      setCanisterAddr(addr);
    })
  },[])

  const fetchNodeInfo = async () => {
    try{
      await window.webln.enable();
      const newInfo = await window.webln.getInfo();
      const newBalance = await window.webln.getBalance();
      setNodeInfo({
        node: newInfo.node,
        balance: newBalance.balance
      })
    } catch(err){
      console.log(err)
    }
  }

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <p>Welcome to RSK Lightning Bridge!</p>
        <p>Follow the steps below to bridge your assets.</p>
      </div>
      {
        typeof(window.webln) !== 'undefined' &&

          <div className={styles.balance}>
            <button className={styles.button} onClick={fetchNodeInfo}>Fetch Node Info</button>
            {
              nodeInfo &&
              <>
              <p>Alias {nodeInfo.node.alias}</p>
              <p>Pubkey {nodeInfo.node.pubkey}</p>
              <p>Balance: {nodeInfo.balance} sats</p>
              </>
            }
          </div>
      }
      {
        coinbase &&
        <div className={styles.balance}>
          <p>EVM connected as {coinbase}</p>
          <p>Your RSK Balance: {rskBalance/10**10} satoshis of rbtc</p>
        </div>
      }
      <div className={styles.tabs}>
        <button
          className={activeTab === 'rskToLight' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('rskToLight');
          }}
        >
          EVM to Lightning
        </button>
        <button
          className={activeTab === 'lightToRSK' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('lightToRSK');
          }}
        >
          Lightning to EVM
        </button>
        <button
          className={activeTab === 'evmToEvm' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('evmToEvm');
          }}
        >
          EVM to EVM
        </button>
        <button
          className={activeTab === 'nostrEvents' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('nostrEvents');
          }}
        >
          Nostr Events
        </button>
      </div>

      {
        activeTab === 'rskToLight' ?
        <EvmToLightning 
            coinbase={coinbase}
            netId={netId}
            provider={provider}
            canisterAddr={canisterAddr}
            loadWeb3Modal={loadWeb3Modal}
        /> :
        activeTab === 'lightToRSK' ?
        <LightningToEvm 
            chains={chains}
        /> :
        activeTab==='evmToEvm'?
        <EvmToEvm 
            coinbase={coinbase}
            netId={netId}
            provider={provider}
            canisterAddr={canisterAddr}
            loadWeb3Modal={loadWeb3Modal}
            chains={chains}
        /> :
        <NostrEvents />
      }

    </div>
  );

};

export default App;