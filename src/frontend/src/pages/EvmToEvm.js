import React, { useContext, useState, useEffect } from "react";
import { useSearchParams } from 'react-router-dom';
import { InfoCircledIcon } from "@radix-ui/react-icons";

import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json'; 
import { main } from "../../../declarations/main";

import { AppContext } from '../AppContext';

import TransactionsList from "../components/TransactionsList";
import {
  Alert,
  AlertDescription,
  AlertTitle,
} from "../components/ui/Alert"
const EvmToEvm = () => {
  const [searchParams] = useSearchParams();

  const { 
    netId,
    coinbase,
    provider,
    canisterAddr,
    loadWeb3Modal,
    chains,
    EXPLORER_BASEURL,
    evm_address,
    evm_txHash,
    setEvmTxHash,
    processing,
    setProcessing,
  } = useContext(AppContext);

  const [message, setMessage] = useState('');
  const [chain, setChain] = useState();
  const [amount, setAmount] = useState('');
  const [originChain, setOriginChain] = useState('');
  const [destinationChain, setDestinationChain] = useState('');

  const sendTxHash = async () => {
    setProcessing(true);
    try {
      let resp;
      const signer = await provider.getSigner();
      const transaction = await provider.getTransaction(evm_txHash);
      if (!transaction) {
        setMessage(`No transaction found`);
        setTimeout(() => {
          setMessage();
        }, 5000);
        return;
      }
      setMessage("Sign transaction hash");
      const signature = await signer.signMessage(transaction.hash);
      console.log(signature)
      setMessage("Verifying parameters to process evm payment");
      const wbtcAddressWanted = chains.filter(item => item.chainId === Number(JSON.parse(chain).chainId))[0].wbtcAddress;
      const wbtcAddressSent = chains.filter(item => item.chainId === Number(netId))[0].wbtcAddress;
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
    try {
      if (!provider) {
        await loadWeb3Modal();
      }
      const signer = await provider.getSigner();
      setMessage(`Sending token to ${canisterAddr}`);
      let tx;
      setEvmTxHash();
      if (Number(netId) === 31) {
        tx = await signer.sendTransaction({
          to: `0x${canisterAddr}`,
          value: ethers.parseUnits(amount.toString(), 10)
        });
      } else {
        const wbtcAddress = chains.filter(item => item.chainId === Number(netId))[0].wbtcAddress;
        const tokenContract = new ethers.Contract(wbtcAddress, ERC20ABI, signer);
        tx = await tokenContract.transfer(`0x${canisterAddr}`, ethers.parseUnits(amount.toString(), 10));
      }
      console.log("Transaction sent:", tx.hash);
      setMessage(<>Tx sent: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a></>);
      const  previousSwaps = localStorage.getItem('EvmToEvm_previousSwaps') ? JSON.parse(localStorage.getItem('EvmToEvm_previousSwaps')) : [];
      console.log(previousSwaps)
      previousSwaps.unshift(JSON.stringify({
        txHash: tx.hash,
        netId: tx.chainId.toString(),
        chain: tx.chain
      }));
      console.log(previousSwaps)
      localStorage.setItem('EvmToEvm_previousSwaps',JSON.stringify(previousSwaps));
      setEvmTxHash(tx.hash);
      await tx.wait();
      setMessage(<>Tx confirmed: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a>, generate invoice and ask payment</>);
    } catch (err) {
      console.log(err)
      setMessage(err.message);
      setTimeout(() => {
        setMessage()
      }, 5000);
    }
    setProcessing(false);
  };

  useEffect(() => {
    const urlAmount = searchParams.get('amount');
    const urlDestinationChain = searchParams.get('destinationChain');
    const urlOriginChain = searchParams.get('originChain');
    setAmount(urlAmount);
    setDestinationChain(urlDestinationChain);
    setChain(urlDestinationChain);
    setOriginChain(urlOriginChain);
    if(urlOriginChain && coinbase && netId){
      if(Number(JSON.parse(urlOriginChain).chainId) !== Number(netId)){
        alert("wrong network, making metamask change network")
      }
    }
  },[]);

  return (
    <div className="w-full p-4">
      <h1 className="text-2xl font-bold text-center mb-6">EVM to EVM Swap</h1>

      {/* Step 1 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 1: Send token to 0x{canisterAddr}</h2>
        {
        originChain &&
        <p className="text-sm text-gray-600">
            Bridging from <strong>{JSON.parse(originChain).name}</strong> (Chain ID: {JSON.parse(originChain).chainId})
        </p>
        }
        {
        destinationChain &&
        <p className="text-sm text-gray-600">
            Bridging to <strong>{JSON.parse(destinationChain).name}</strong> (Chain ID: {JSON.parse(destinationChain).chainId})
        </p>
        }
        {
        amount &&
        <p className="text-sm text-gray-600">
            Amount: {amount} satoshis
        </p>
        }
        {
          !coinbase ?
            <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={loadWeb3Modal}>Connect Wallet</button> :
            !processing ?
              <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={sendToken}>Send token</button> :
              <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" disabled>Wait current process</button>
        }
      </div>

      {/* Step 3 */}
      {
        evm_txHash &&
        <div className="mb-6">
          <h2 className="text-xl font-semibold mb-4">Step 2: Input evm transaction hash</h2>
          <label className="block mb-2">Transaction Hash</label>
          <input
            className="w-full p-2 border border-gray-300 rounded mb-4"
            value={evm_txHash}
            onChange={(ev) => setEvmTxHash(ev.target.value)}
            placeholder="Transaction Hash"
          />
          {
            !processing ?
              <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={sendTxHash}>Finalize swap</button> :
              <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" disabled>Wait current process</button>
          }
        </div>
      }

      {/* Message Display */}
      {message && (
        <Alert variant="info">
          <InfoCircledIcon className="h-4 w-4" />
          <AlertTitle>Info</AlertTitle>
          <AlertDescription>
            {message}
          </AlertDescription>
        </Alert>
      )}
      <TransactionsList 
        name={'EvmToEvm'}
        netId={netId}
        setEvmTxHash={setEvmTxHash}
      />
    </div>
  );
};

export default EvmToEvm;