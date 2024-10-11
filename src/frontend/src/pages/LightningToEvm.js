import React, { useState, useEffect } from "react";
import { ethers } from 'ethers';
import { main } from "../../../declarations/main";

const LightningToEvm = ({ chains, coinbase }) => {
  const [message, setMessage] = useState('');
  const [processing, setProcessing] = useState(false);
  const [amount, setAmount] = useState('');
  const [r_hash, setPaymentHash] = useState('');
  const [invoiceToPay, setInvoiceToPay] = useState('');
  const [evm_address, setEvmAddr] = useState('');
  const [chain, setChain] = useState('');
  const [alertSeverity, setAlertSeverity] = useState('info');

  const getInvoice = async () => {
    setProcessing(true);
    try {
      setMessage("Getting invoice from service...");
      const resp = await main.generateInvoiceToSwapToRsk(Number(amount), evm_address, new Date().getTime().toString());
      const respJson = JSON.parse(resp);
      const invoice = respJson.payment_request;
      const base64PaymentHash = respJson.r_hash;
      setPaymentHash(base64PaymentHash);
      setInvoiceToPay(invoice);
      const r_hashUrl = base64PaymentHash.replace(/\+/g, '-').replace(/\//g, '_');
      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        setMessage(`Paying invoice...`);
        await window.webln.sendPayment(invoice);
        setMessage("Invoice paid, waiting for transaction...");
        const invoiceCheckResp = await main.swapLN2EVM(ethers.toBeHex(JSON.parse(chain).chainId), r_hashUrl, new Date().getTime().toString());
        setMessage(invoiceCheckResp);
      } else {
        setMessage(`Please pay the invoice and proceed to Step 2.`);
      }
      setAlertSeverity('success');
    } catch (err) {
      setMessage(`Error: ${err.message}`);
      setAlertSeverity('error');
    }
    setProcessing(false);
  };

  const checkInvoice = async () => {
    setProcessing(true);
    try {
      setMessage("Processing EVM transaction...");
      const selectedChain = JSON.parse(chain);
      const wbtcAddressWanted = chains.find(item => item.chainId === Number(selectedChain.chainId))?.wbtcAddress || "0";

      const resp = await main.swapLN2EVM(
        ethers.toBeHex(selectedChain.chainId),
        wbtcAddressWanted,
        r_hash.replace(/\+/g, '-').replace(/\//g, '_'),
        new Date().getTime().toString()
      );
      setMessage(resp);
      setAlertSeverity('success');
    } catch (err) {
      setMessage(`Error: ${err.message}`);
      setAlertSeverity('error');
    }
    setProcessing(false);
  };

  useEffect(() => {
    if (coinbase) {
      setEvmAddr(coinbase);
    }
  }, [coinbase]);

  useEffect(() => {
    if (chains && chains.length > 0) {
      const initialChain = JSON.stringify({
        rpc: chains[0].rpc.find(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}")),
        chainId: chains[0].chainId,
        name: chains[0].name,
      });
      setChain(initialChain);
    }
  }, [chains]);

  return (
    <div className="flex-grow max-w-3xl mx-auto p-4">
      <h1 className="text-2xl font-bold text-center mb-6">Lightning to EVM Swap</h1>

      {/* Step 1 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 1: Request an Invoice</h2>
        <input
          type="number"
          placeholder="Amount (satoshi)"
          value={amount}
          onChange={(ev) => setAmount(ev.target.value)}
          className="w-full p-2 border border-gray-300 rounded mb-4"
        />
        <input
          type="text"
          placeholder="EVM Recipient Address"
          value={evm_address}
          onChange={(ev) => setEvmAddr(ev.target.value)}
          className="w-full p-2 border border-gray-300 rounded mb-4"
        />
        <select
          value={chain}
          onChange={(ev) => setChain(ev.target.value)}
          className="w-full p-2 border border-gray-300 rounded mb-4"
        >
          {chains.map((item, index) => (
            <option
              key={index}
              value={JSON.stringify({
                rpc: item.rpc.find(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}")),
                chainId: item.chainId,
                name: item.name,
              })}
            >
              {item.name}
            </option>
          ))}
        </select>
        {chain && (
          <p className="text-sm text-gray-600">
            Bridging to <strong>{JSON.parse(chain).name}</strong> (Chain ID: {JSON.parse(chain).chainId})
          </p>
        )}
        <button
          onClick={getInvoice}
          disabled={processing}
          className={`w-full p-2 rounded mt-3 ${processing ? 'bg-gray-400' : 'bg-blue-500 text-white hover:bg-blue-600'}`}
        >
          {processing ? 'Loading...' : 'Get Invoice'}
        </button>
        {invoiceToPay && (
          <div className="bg-blue-100 text-blue-700 p-3 rounded mt-3 break-all">
            <strong>Invoice to be paid:</strong> {invoiceToPay}
          </div>
        )}
      </div>

      {/* Step 2 */}
      <div className="mb-6">
        <h2 className="text-xl font-semibold mb-4">Step 2: Input Payment Hash</h2>
        <input
          type="text"
          placeholder="Payment Hash (r_hash)"
          value={r_hash}
          onChange={(ev) => setPaymentHash(ev.target.value)}
          className="w-full p-2 border border-gray-300 rounded mb-4"
        />
        <button
          onClick={checkInvoice}
          disabled={processing}
          className={`w-full p-2 rounded mt-3 ${processing ? 'bg-gray-400' : 'bg-green-500 text-white hover:bg-green-600'}`}
        >
          {processing ? 'Loading...' : 'Check Invoice'}
        </button>
      </div>

      {/* Message Display */}
      {message && (
        <div className={`p-3 rounded mt-3 break-all ${alertSeverity === 'success' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
          {message}
        </div>
      )}
    </div>
  );
};

export default LightningToEvm;