import React, { useState,useEffect } from "react";

import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json'; 
import { main } from "../../../declarations/main";
import styles from '../RSKLightningBridge.module.css';  // Import the CSS module
const EvmToLightning = ({
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
  const [userInvoice,setUserInvoice] = useState();
  const [amount, setAmount] = useState('');
  const [EXPLORER_BASEURL,setExplorerBaseUrl] = useState("https://explorer.testnet.rsk.co/tx/");

  const decodeERC20Transfer = async (txInput) => {
    const iface = new ethers.Interface(ERC20ABI);
    const decodedInput = await iface.parseTransaction({ data: txInput });
    console.log(`Tx decoded`);
    console.log(decodedInput);
    return decodedInput.args;
  }
  const sendInvoiceAndTxHash = async () => {
      setProcessing(true);
      try {
        let resp;
        let paymentRequest;
        const signer = await provider.getSigner();
        const transaction = await provider.getTransaction(evm_txHash);
        if(!transaction){
          setMessage(`No transaction found`);
          setTimeout(() => {
            setMessage();
          },5000);
          return;
        }
        if (typeof window.webln !== 'undefined') {
          await window.webln.enable();
          setMessage("Preparing invoice");
          let sats;
          if(netId === 31){
            sats = Number(transaction.value)/10**10
          } else {
            const decodedTxArgs = await decodeERC20Transfer(transaction.data);
            console.log('Decoded transaction:', decodedTxArgs);
    
            sats = Number(decodedTxArgs[1])/10**10
          };          const invoice = await webln.makeInvoice({
            amount: sats,
            defaultMemo: `Chain ${ethers.toBeHex(netId)} - Tx Hash ${transaction.hash}`
          });
          setMessage(`Sending invoice ${invoice.paymentRequest}`);
          paymentRequest = invoice.paymentRequest
        } else {
          paymentRequest = userInvoice;
        }
        setMessage("Sign transaction hash");
        //const signature = await signer.sign(transaction.hash);
        //const hashedMsg = ethers.hashMessage(`\x19Ethereum Signed Message:\ntest`)
        const signature = await signer.signMessage(transaction.hash);
        console.log(signature)
        //resp = await main.payInvoicesAccordingToEvents(new Date().getTime().toString());
        setMessage("Service processing lightning payment");
        const wbtcAddressSent = chains.filter(item => {return item.chainId === Number(netId)})[0].wbtcAddress;
        resp = await main.swapEVM2LN(
          {
            proofTxId: transaction.hash,
            invoiceId: paymentRequest,
            sendingChain: ethers.toBeHex(netId),
            sentERC20: wbtcAddressSent ? wbtcAddressSent : "0",
            recipientChain: ethers.toBeHex(netId),
            wantedERC20: "0",
            recipientAddress: `0x${canisterAddr}`,
            signature: signature,
            reward: "0"
          },
          new Date().getTime().toString()
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
  return(
  <>
  <div>
      {/* Content for EVM to Lightning */}
      {
      coinbase && netId &&
      <div className={styles.step}>
          <p>ChainId: {netId.toString()}</p>
      </div>
      }
      <div className={styles.step}>
      <p>Step 1: Send token to 0x{canisterAddr}</p>
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
          <button className={styles.button} disabled>Wait current process</button>
      }
      </div>
      <div className={styles.step}>
      <p>Step 2: Input evm transaction hash and lightning invoice</p>
      <label className={styles.label}>Transaction Hash</label>
      <input
          className={styles.input}
          value={evm_txHash}
          onChange={(ev) => setEvmTxHash(ev.target.value)}
          placeholder="Transaction Hash"
      />
      {
          typeof(window.webln) == 'undefined' &&
          <>
          <label className={styles.label}>Invoice</label>
          <input
          className={styles.input}
          value={userInvoice}
          onChange={(ev) => setUserInvoice(ev.target.value)}
          placeholder="Enter Invoice"
          />
          </>
      }
      {
          !processing ?
          <button className={styles.button} onClick={sendInvoiceAndTxHash} >Prepare and send invoice</button> :
          <button className={styles.button} disabled>Wait current process</button>
      }
      </div>
  </div>
  <div style={{overflowX: "auto"}}>
        <span className={styles.message}>{message}</span>
  </div>
  </>
  );
};
export default EvmToLightning;