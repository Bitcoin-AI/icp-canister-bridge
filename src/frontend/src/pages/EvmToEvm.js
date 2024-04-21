import React, { useState,useEffect } from "react";

import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json'; 

import { main } from "../../../declarations/main";
import styles from '../RSKLightningBridge.module.css';  // Import the CSS module
const EvmToEvm = ({
  coinbase,
  netId,
  provider,
  canisterAddr,
  loadWeb3Modal,
  chains
}) => {
  const [message, setMessage] = useState('');
  const [processing,setProcessing] = useState();
  const [evm_txHash,setEvmTxHash] = useState();
  const [evm_address, setEvmAddr] = useState('');
  const [chain,setChain] = useState();
  const [amount,setAmount] = useState();
  const [EXPLORER_BASEURL,setExplorerBaseUrl] = useState("https://explorer.testnet.rsk.co/tx/");

  const sendTxHash = async () => {
    setProcessing(true);
    try {
      let resp;
      const signer = await provider.getSigner();
      const transaction = await provider.getTransaction(evm_txHash);
      if(!transaction){
        setMessage(`No transaction found`);
        setTimeout(() => {
          setMessage();
        },5000);
        return;
      }
      //const signature = await signer.sign(`\x19Ethereum Signed Message:\n${transaction.hash}`);
      setMessage("Sign transaction hash");
      //const signature = await signer.sign(transaction.hash);
      //const hashedMsg = ethers.hashMessage(`\x19Ethereum Signed Message:\ntest`)
      const signature = await signer.signMessage(transaction.hash);
      console.log(signature)
      // Do eth tx and then call main.payInvoicesAccordingToEvents();
      //resp = await main.payInvoicesAccordingToEvents(new Date().getTime().toString());
      setMessage("Verifying parameters to process evm payment");
      const wbtcAddressWanted = chains.filter(item => {return item.chainId === Number(JSON.parse(chain).chainId)})[0].wbtcAddress;
      const wbtcAddressSent = chains.filter(item => {return item.chainId === Number(netId)})[0].wbtcAddress;
      resp = await main.swapEVM2EVM(
        {
          proofTxId: transaction.hash,
          invoiceId: "null",
          sendingChain: ethers.toBeHex(netId),
          sentERC20: wbtcAddressSent ? wbtcAddressSent : "0",
          recipientChain: ethers.toBeHex(JSON.parse(chain).chainId),
          wantedERC20: wbtcAddressWanted ? wbtcAddressWanted : "0",
          recipientAddress: evm_address,
          signature: signature,
          reward: "0"
        }
      );
      setMessage(resp);
    } catch (err) {
      setMessage(err.message);
    }
    setProcessing(false);
  };
  const sendToken = async () => {
      setProcessing(true);
      try{
        // Send the transaction
        if(!provider){
          await loadWeb3Modal();
        }
        const signer = await provider.getSigner();
  
        //const bridgeWithSigner = bridge.connect(signer);
        setMessage(`Sending token to ${canisterAddr}`);
        //const tx = await bridgeWithSigner.swapToLightningNetwork(amount * 10 ** 10, paymentRequest, { value: amount * 10 ** 10 });
        // Change for wbtc or rsk transaction based on ChainId
        let tx;
        if(Number(netId) === 31){
          tx = await signer.sendTransaction({
            to: `0x${canisterAddr}`,
            value: ethers.parseUnits(amount.toString(),10)
          });
        } else {
          // Connect contract and do transaction;
          const wbtcAddress = chains.filter(item => {return item.chainId === Number(netId)})[0].wbtcAddress;
          const tokenContract = new ethers.Contract(wbtcAddress, ERC20ABI, signer);
          tx = await tokenContract.transfer(`0x${canisterAddr}`, ethers.parseUnits(amount.toString(), 10));
        }

        console.log("Transaction sent:", tx.hash);
        // Use explorers based on chainlist
        setMessage(<>Tx sent: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a></>);
        // Wait for the transaction to be mined
        await tx.wait();
        setMessage(<>Tx confirmed: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a>, generate invoice and ask payment</>);
        setEvmTxHash(tx.hash);
      } catch(err){
        console.log(err)
        setMessage(err.message);
        setTimeout(() => {
          setMessage()
        },5000);
      }
      setProcessing(false);
  };
  useEffect(() => {
    if(netId === 31){
      setExplorerBaseUrl("https://explorer.testnet.rsk.co/tx/");
    } else {
      setExplorerBaseUrl("https://sepolia.etherscan.io/tx/");
    }
  },[netId]);
  useEffect(() => {
    if (coinbase) {
      setEvmAddr(coinbase);
    }
  }, [coinbase]);
  useEffect(() => {
    if(netId === 31){
      setExplorerBaseUrl("https://explorer.testnet.rsk.co/tx/");
    } else {
      setExplorerBaseUrl("https://sepolia.etherscan.io/tx/");
    }
  },[netId]);
  useEffect(() => {
    if(chains){
      const initialChain = JSON.stringify(
        {
          rpc: chains[0].rpc.filter(rpcUrl => {
            if(!rpcUrl.includes("${INFURA_API_KEY}")) return rpcUrl;
          })[0],
          chainId: chains[0].chainId,
          name: chains[0].name
        }
      );
      setChain(initialChain);
    }
  },[chains]);
  return(
  <>
  <div>
    {/* Content for Lightning to RSK */}
    <div className={styles.step}>
      <p>Step 1: Select recipient and EVM compatible chain</p>
      <label className={styles.label}>EVM Recipient Address</label>
      <input
        className={styles.input}
        value={evm_address}
        onChange={(ev) => setEvmAddr(ev.target.value)}
        placeholder="Enter EVM address"
      />
      <label className={styles.label}>Select Destiny Chain</label>
      <select
        className={styles.input}
        type="select"
        onChange={(ev) => setChain(ev.target.value)}
      >
      {
        chains.map(item => {
          return(<option key={item.chainId} value={JSON.stringify(
            {
              rpc: item.rpc.filter(rpcUrl => {
                if(!rpcUrl.includes("${INFURA_API_KEY}")) return rpcUrl;
              })[0],
              chainId: item.chainId,
              name: item.name
            }
          )}>{item.name}</option>)
        })
      }
      </select>
      {
        chain &&
        <>
        <p>Bridging to {JSON.parse(chain).name}</p>
        <p>ChainId {JSON.parse(chain).chainId}</p>
        </>

      }
    </div>
    <div class={styles.step}>
      <p>Step 2: Send token to 0x{canisterAddr}</p>
      <label className={styles.label}>Amount in satoshis</label>
      <input
        className={styles.input}
        value={amount}
        onChange={(ev) => setAmount(ev.target.value)}
        placeholder="Satoshis"
      />
      {
        !coinbase ?
          <button className={styles.button} onClick={loadWeb3Modal}>Connect Wallet</button> :
        !processing ?
        <button className={styles.button} onClick={sendToken} >Send token</button> :
        <button className={styles.button} disabled >Wait current process</button>
      }
    </div>
    {
      coinbase && netId &&
      <div class={styles.step}>
        <p>Sending from chainId {netId.toString()}</p>
      </div>
    }
    <div class={styles.step}>
      <p>Step 3: Input evm transaction hash</p>
      <label className={styles.label}>Transaction Hash</label>
      <input
        className={styles.input}
        value={evm_txHash}
        onChange={(ev) => setEvmTxHash(ev.target.value)}
        placeholder="Transaction Hash"
      />
      {
        !processing ?
        <button className={styles.button} onClick={sendTxHash}>Finalize swap</button> :
        <button className={styles.button} disabled >Wait current process</button>
      }
    </div>
  </div>
  <div style={{overflowX: "auto"}}>
        <span className={styles.message}>{message}</span>
  </div>
  </>
  );
};
export default EvmToEvm;