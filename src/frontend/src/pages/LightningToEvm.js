import React, { useState, useEffect } from "react";
import { ethers } from 'ethers';
import { main } from "../../../declarations/main";
import {
  Box,
  Button,
  TextField,
  Select,
  MenuItem,
  InputLabel,
  FormControl,
  Typography,
  CircularProgress,
  Alert,
} from '@mui/material';
import { LoadingButton } from '@mui/lab';

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
    <Box sx={{ maxWidth: 600, margin: '0 auto', padding: 4 }}>
      <Typography variant="h4" gutterBottom align="center">
        Lightning to EVM Swap
      </Typography>

      {/* Step 1 */}
      <Box sx={{ marginBottom: 6 }}>
        <Typography variant="h6" gutterBottom>
          Step 1: Request an Invoice
        </Typography>
        <TextField
          label="Amount (satoshi)"
          variant="outlined"
          fullWidth
          margin="normal"
          value={amount}
          onChange={(ev) => setAmount(ev.target.value)}
          type="number"
        />
        <TextField
          label="EVM Recipient Address"
          variant="outlined"
          fullWidth
          margin="normal"
          value={evm_address}
          onChange={(ev) => setEvmAddr(ev.target.value)}
        />
        <FormControl variant="outlined" fullWidth margin="normal">
          <InputLabel>Destination Chain</InputLabel>
          <Select
            label="Destination Chain"
            value={chain}
            onChange={(ev) => setChain(ev.target.value)}
          >
            {chains.map((item, index) => (
              <MenuItem key={index} value={JSON.stringify({
                rpc: item.rpc.find(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}")),
                chainId: item.chainId,
                name: item.name,
              })}>
                {item.name}
              </MenuItem>
            ))}
          </Select>
        </FormControl>
        {chain && (
          <Typography variant="body2" color="textSecondary">
            Bridging to <strong>{JSON.parse(chain).name}</strong> (Chain ID: {JSON.parse(chain).chainId})
          </Typography>
        )}
        <LoadingButton
          variant="contained"
          color="primary"
          onClick={getInvoice}
          loading={processing}
          sx={{ marginTop: 3 }}
          size="large"
          fullWidth
        >
          Get Invoice
        </LoadingButton>
        {invoiceToPay && (
          <Alert severity="info" sx={{ marginTop: 3, wordBreak: 'break-all' }}>
            <strong>Invoice to be paid:</strong> {invoiceToPay}
          </Alert>
        )}
      </Box>

      {/* Step 2 */}
      <Box sx={{ marginBottom: 6 }}>
        <Typography variant="h6" gutterBottom>
          Step 2: Input Payment Hash
        </Typography>
        <TextField
          label="Payment Hash (r_hash)"
          variant="outlined"
          fullWidth
          margin="normal"
          value={r_hash}
          onChange={(ev) => setPaymentHash(ev.target.value)}
        />
        <LoadingButton
          variant="contained"
          color="secondary"
          onClick={checkInvoice}
          loading={processing}
          sx={{ marginTop: 3 }}
          size="large"
          fullWidth
        >
          Check Invoice
        </LoadingButton>
      </Box>

      {/* Message Display */}
      {message && (
        <Alert severity={alertSeverity} sx={{ marginTop: 3, wordBreak: 'break-all' }}>
          {message}
        </Alert>
      )}
    </Box>
  );
};

export default LightningToEvm;