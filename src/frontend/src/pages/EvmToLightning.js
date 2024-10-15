import React, { useState, useEffect } from "react";
import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json'; 
import { main } from "../../../declarations/main";

const EvmToLightning = ({
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
  const [userInvoice, setUserInvoice] = useState();
  const [amount, setAmount] = useState('');
  const [EXPLORER_BASEURL, setExplorerBaseUrl] = useState("https://explorer.testnet.rsk.co/tx/");

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
      if (!transaction) {
        setMessage(`No transaction found`);
        setTimeout(() => {
          setMessage();
        }, 5000);
        return;
      }
      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        setMessage("Preparing invoice");
        let sats;
        if (netId === 31) {
          sats = Number(transaction.value) / 10 ** 10
        } else {
          const decodedTxArgs = await decodeERC20Transfer(transaction.data);
          console.log('Decoded transaction:', decodedTxArgs);

          sats = Number(decodedTxArgs[1]) / 10 ** 10
        };
        const invoice = await webln.makeInvoice({
          amount: sats,
          defaultMemo: `Chain ${ethers.toBeHex(netId)} - Tx Hash ${transaction.hash}`
        });
        setMessage(`Sending invoice ${invoice.paymentRequest}`);
        paymentRequest = invoice.paymentRequest
      } else {
        paymentRequest = userInvoice;
      }
      setMessage("Sign transaction hash");
      const signature = await signer.signMessage(transaction.hash);
      console.log(signature)
      setMessage("Service processing lightning payment");
      const wbtcAddressSent = chains.filter(item => { return item.chainId === Number(netId) })[0].wbtcAddress;
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
        const wbtcAddress = chains.filter(item => { return item.chainId === Number(netId) })[0].wbtcAddress;
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
    if (Number(netId) === 31) {
      setExplorerBaseUrl("https://explorer.testnet.rsk.co/tx/");
    } else {
      setExplorerBaseUrl("https://sepolia.etherscan.io/tx/");
    }
  }, [netId]);

  return (
    <div className="w-full p-4">
      <h1 className="text-2xl font-bold text-center mb-6">EVM to Lightning Swap</h1>

      {/* Step 1 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 1: Send token to 0x{canisterAddr}</h2>
        <label className="block mb-2">Amount in satoshis</label>
        <input
          type="number"
          placeholder="Satoshis"
          value={amount}
          onChange={(ev) => setAmount(ev.target.value)}
          className="w-full p-2 border border-gray-300 rounded mb-4"
        />
        {
          !coinbase ?
            <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={loadWeb3Modal}>Connect Wallet</button> :
            !processing ?
              <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={sendToken}>Send token</button> :
              <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" disabled>Wait current process</button>
        }
      </div>

      {/* Step 2 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 2: Input evm transaction hash and lightning invoice</h2>
        <label className="block mb-2">Transaction Hash</label>
        <input
          type="text"
          placeholder="Transaction Hash"
          value={evm_txHash}
          onChange={(ev) => setEvmTxHash(ev.target.value)}
          className="w-full p-2 border border-gray-300 rounded mb-4"
        />
        {
          typeof (window.webln) == 'undefined' &&
          <>
            <label className="block mb-2">Invoice</label>
            <input
              type="text"
              placeholder="Enter Invoice"
              value={userInvoice}
              onChange={(ev) => setUserInvoice(ev.target.value)}
              className="w-full p-2 border border-gray-300 rounded mb-4"
            />
          </>
        }
        {
          !processing ?
            <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={sendInvoiceAndTxHash}>Prepare and send invoice</button> :
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

export default EvmToLightning;