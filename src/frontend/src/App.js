import React, { useState, useEffect,useCallback } from "react";
import { ethers } from 'ethers';
import { HashRouter as Router, Route, Routes,Navigate,Link } from 'react-router-dom';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faBolt,faLightbulb, faExchangeAlt, faPaperPlane, faBullhorn } from '@fortawesome/free-solid-svg-icons';
import { main } from "../../declarations/main";

import useWeb3Modal from "./hooks/useWeb3Modal";

import styles from './RSKLightningBridge.module.css';  // Import the CSS module

import Header from "./components/Header";


import EvmToLightning from "./pages/EvmToLightning";
import EvmToEvm from "./pages/EvmToEvm";
import LightningToEvm from "./pages/LightningToEvm";
import Petitions from "./pages/Petitions";
import PetitionsLN from "./pages/PetitionsLN";


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

  const wbtcAddresses = {
    '1': '0x2260fac5e5542a773aa44fbcfedf7c193bc2c599', // Ethereum Mainnet
    '8453': '0x1ceA84203673764244E05693e42E6Ace62bE9BA5', // Base 
    '2222': '0xD359A8549802A8122C4cfe5d84685e347E22E946', // Kava
    '11155111': '0x0311FC95124Ca345a3913b6133028Ac8DEe47AA5' // Sepolia
  };

  useEffect(() => {
    let rpcNodes = [];
    fetch("https://chainid.network/chains.json").then(async response => {
      const chainsResp = await response.json();
      chainsResp.map(item => {
        const rpc = item.rpc.filter(rpc => {
          if((rpc.indexOf("INFURA_API_KEY") !== -1 && rpc.indexOf("sepolia") !== -1) ||
             (rpc.indexOf("rsk") !== -1 && rpc.indexOf("testnet") !== -1)){
            return(rpc)
          }
        });
        if(rpc.length > 0){
          console.log(item)
          if(wbtcAddresses[item.chainId.toString()]){
            rpcNodes.push({
              ...item,
              wbtcAddress: wbtcAddresses[item.chainId.toString()].toLowerCase()
            });
          } else {
            rpcNodes.push(item);
          }
        }
      });
      setChains(rpcNodes);
    });
  }, []);





  const fetchUserBalance = useCallback(async () => {
    if (coinbase && netId && provider) {
      try {
        let balance;
        if(netId === 31){
          balance = await provider.getBalance(coinbase);
        } else {
          const wbtcAddress = wbtcAddresses[netId.toString()];
          const erc20Contract = new ethers.Contract(wbtcAddress, ['function balanceOf(address) view returns (uint)'], provider);
          balance = await erc20Contract.balanceOf(coinbase);
        }
        setUserBalance(balance.toString());
      } catch (error) {
        setUserBalance("0");

        console.error("Error fetching user balance:", error);
      }
    }
  }, [coinbase, netId,provider]);

  useEffect(() => {
    fetchUserBalance(); // Fetch balance immediately when component mounts or coinbase/bridge changes

    const intervalId = setInterval(fetchUserBalance, 30000); // Fetch balance every 30 seconds


    return () => clearInterval(intervalId); // Clear interval on component unmount
  }, [fetchUserBalance]);
  

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
      <Header
        nodeInfo={nodeInfo}
        netId={netId}
        coinbase={coinbase}
        fetchNodeInfo={fetchNodeInfo}
        rskBalance={rskBalance}
      />

      <Router>
          <div className={styles.tabs}>
            <Link to='/'>
              <button
                className={activeTab === 'rskToLight' ? styles.activeTab : ''}
                onClick={() => {
                  setActiveTab('rskToLight');
                }}
              >
                <FontAwesomeIcon icon={faBolt} /> EVM to Lightning
              </button>
            </Link>
            <Link to='/lightningToEvm'>
              <button
                className={activeTab === 'lightToRSK' ? styles.activeTab : ''}
                onClick={() => {
                  setActiveTab('lightToRSK');
                }}
              >
                <FontAwesomeIcon icon={faExchangeAlt} /> Lightning to EVM
              </button>
            </Link>
            <Link to="/evmToEvm">
              <button
                className={activeTab === 'evmToEvm' ? styles.activeTab : ''}
                onClick={() => {
                  setActiveTab('evmToEvm');
                }}
              >
                <FontAwesomeIcon icon={faExchangeAlt} /> EVM to EVM
              </button>
            </Link>
            <Link to='/petitionsEvm'>
              <button
                className={activeTab === 'petitions' ? styles.activeTab : ''}
                onClick={() => {
                  setActiveTab('petitions');
                }}
              >
                <FontAwesomeIcon icon={faPaperPlane} /> Petitions EVM to EVM
              </button>
            </Link>
            <Link to="/petitionsLN">
              <button
                className={activeTab === 'petitionsLN' ? styles.activeTab : ''}
                onClick={() => {
                  setActiveTab('petitionsLN');
                }}
              >
                <FontAwesomeIcon icon={faBullhorn} /> Petitions between LN and EVM
              </button>
            </Link>
          </div>
          {
            !canisterAddr &&
            <p>Loading Canister ...</p>
          }
          <Routes>
            <Route path="/" element={
              <>
              {
                canisterAddr && 
                <EvmToLightning 
                  coinbase={coinbase}
                  netId={netId}
                  provider={provider}
                  canisterAddr={canisterAddr}
                  loadWeb3Modal={loadWeb3Modal}
                  chains={chains}
                /> 
              }
              </>

            } 

            />
            <Route path="/lightningToEvm" element={
              <>
              {
                canisterAddr && 
                <LightningToEvm 
                  chains={chains}
                  coinbase={coinbase}
                />
              }
              </>
            }
            />
            <Route path="/evmToEvm" element={
              <>
              {
                canisterAddr &&
                <EvmToEvm 
                  coinbase={coinbase}
                  netId={netId}
                  provider={provider}
                  canisterAddr={canisterAddr}
                  loadWeb3Modal={loadWeb3Modal}
                  chains={chains}          
                />
              }
              </>
            } 

            />
            <Route path="/petitionsEvm" element={
              <>
              {
                canisterAddr &&
                <Petitions
                  coinbase={coinbase}
                  netId={netId}
                  provider={provider}
                  canisterAddr={canisterAddr}
                  loadWeb3Modal={loadWeb3Modal}
                  chains={chains}
                />
              }
              </>
            } 
            />
            <Route path="/petitionsLN" element={
              <>
              {
                canisterAddr &&
                <PetitionsLN 
                  coinbase={coinbase}
                  netId={netId}
                  provider={provider}
                  canisterAddr={canisterAddr}
                  loadWeb3Modal={loadWeb3Modal}
                  chains={chains}
                />
              }
              </>
            } 
            />
            <Route path="*" element={<Navigate to="/" replace />} />

          </Routes>
      </Router>


    </div>
  );

};

export default App;