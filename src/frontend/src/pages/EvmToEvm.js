import React, { useState, useEffect } from "react";
import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json'; 
import { main } from "../../../declarations/main";

const EvmToEvm = ({
  coinbase,
  netId,
  provider,
  canisterAddr,
  loadWeb3Modal,
  chains
}) => {
  const [message, setMessage] = useState('');
  const [processing, setProcessing] = useState();
  const [evm_txHash, setEvmTxHash] = useState();
  const [evm_address, setEvmAddr] = useState('');
  const [chain, setChain] = useState();
  const [amount, setAmount] = useState();
  const [EXPLORER_BASEURL, setExplorerBaseUrl] = useState("https://explorer.testnet.rsk.co/tx/");

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
      await tx.wait();
      setMessage(<>Tx confirmed: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a>, generate invoice and ask payment</>);
      setEvmTxHash(tx.hash);
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
    if (netId === 31) {
      setExplorerBaseUrl("https://explorer.testnet.rsk.co/tx/");
    } else {
      setExplorerBaseUrl("https://sepolia.etherscan.io/tx/");
    }
  }, [netId]);

  useEffect(() => {
    if (coinbase) {
      setEvmAddr(coinbase);
    }
  }, [coinbase]);

  useEffect(() => {
    if (chains) {
      const initialChain = JSON.stringify(
        {
          rpc: chains[0].rpc.filter(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}"))[0],
          chainId: chains[0].chainId,
          name: chains[0].name
        }
      );
      setChain(initialChain);
    }
  }, [chains]);

  return (
    <div className="flex-grow max-w-3xl mx-auto p-4">
      <h1 className="text-2xl font-bold text-center mb-6">EVM to EVM Swap</h1>

      {/* Step 1 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 1: Select recipient and EVM compatible chain</h2>
        <label className="block mb-2">EVM Recipient Address</label>
        <input
          className="w-full p-2 border border-gray-300 rounded mb-4"
          value={evm_address}
          onChange={(ev) => setEvmAddr(ev.target.value)}
          placeholder="Enter EVM address"
        />
        <label className="block mb-2">Select Destiny Chain</label>
        <select
          className="w-full p-2 border border-gray-300 rounded mb-4"
          onChange={(ev) => setChain(ev.target.value)}
        >
          {
            chains.map(item => (
              <option key={item.chainId} value={JSON.stringify(
                {
                  rpc: item.rpc.filter(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}"))[0],
                  chainId: item.chainId,
                  name: item.name
                }
              )}>{item.name}</option>
            ))
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

      {/* Step 2 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 2: Send token to 0x{canisterAddr}</h2>
        <label className="block mb-2">Amount in satoshis</label>
        <input
          className="w-full p-2 border border-gray-300 rounded mb-4"
          value={amount}
          onChange={(ev) => setAmount(ev.target.value)}
          placeholder="Satoshis"
        />
        {
          !coinbase ?
            <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={loadWeb3Modal}>Connect Wallet</button> :
            !processing ?
              <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={sendToken}>Send token</button> :
              <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" disabled>Wait current process</button>
        }
      </div>

      {/* Step 3 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 3: Input evm transaction hash</h2>
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

      {/* Message Display */}
      {message && (
        <div className="p-3 rounded mt-3 break-all bg-blue-100 text-blue-700">
          {message}
        </div>
      )}
    </div>
  );
};

export default EvmToEvm;