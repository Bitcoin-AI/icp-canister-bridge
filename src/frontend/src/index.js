import React, { useState, useEffect, useCallback } from "react";
import { render } from "react-dom";
import bolt11 from 'bolt11';
import { ethers } from 'ethers';
import { main } from "../../declarations/main";
import useWeb3Modal from "./hooks/useWeb3Modal";
import useNostr from "./hooks/useNostr";
import addresses from "../assets/contracts/addresses";
import abis from "../assets/contracts/abis";
import styles from './RSKLightningBridge.module.css';  // Import the CSS module


const RSKLightningBridge = () => {
  // State hooks
  const [message, setMessage] = useState('');
  const [amount, setAmount] = useState('');
  const [r_hash, setPaymentHash] = useState('');
  const [evm_address, setEvmAddr] = useState('');
  const [memo, setMemo] = useState('');
  const [activeTab, setActiveTab] = useState('rskToLight');
  const [rskBalance, setUserBalance] = useState();
  const [bridge, setBridge] = useState();

  const {
    netId,
    coinbase,
    provider,
    loadWeb3Modal
  } = useWeb3Modal();

  const {
    events,
    npub
  } = useNostr();

  // Effect hook for initializing the bridge
  useEffect(() => {
    if (netId === 31 && provider) {
      const newBridge = new ethers.Contract(addresses.bridge.testnet, abis.bridge, provider);
      setBridge(newBridge);
    }
  }, [netId, provider]);
  useEffect(() => {
    if (coinbase) {
      setEvmAddr(coinbase);
    }
  }, [coinbase])

  const base64UrlEncode = (input) => {
    let base64 = Buffer.from(input, 'hex').toString('base64');
    let base64Url = base64.replace(/\+/g, '-').replace(/\//g, '_');
    return base64Url;
  };

  const getInvoice = async () => {
    try {
      setMessage("Getting invoice from service");
      const resp = await main.generateInvoiceToSwapToRsk(Number(amount), evm_address.replace("0x", ""));
      setMessage(resp);
      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        if (!lightningNodeInfo) {
          fetchLightiningInfo()
        }
        const invoice = JSON.parse(resp).payment_request;
        setPaymentHash(JSON.parse(resp).r_hash);
        setMessage("Pay invoice");
        const result = await window.webln.sendPayment(invoice);
        const r_hash = JSON.parse(resp).r_hash.replace(/\+/g, '-').replace(/\//g, '_');
        setMessage("Invoice payed, wait for service update address's balance in smart contract");
        const invoiceCheckResp = await main.swapFromLightningNetwork(r_hash);
        console.log(invoiceCheckResp);
        setMessage(invoiceCheckResp);
      }
    } catch (err) {
      setMessage(err.message)
    }
  }
  const sendInvoiceAndRBTC = async () => {
    try {
      let resp;
      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        setMessage("Preparing invoice");
        const invoice = await webln.makeInvoice({
          amount: amount,
          defaultMemo: memo
        });
        setMessage(`Invoice: ${invoice.paymentRequest}`);
        // Send the transaction
        const signer = await provider.getSigner();

        const bridgeWithSigner = bridge.connect(signer);
        setMessage(`Storing invoice in smart contract`);
        const tx = await bridgeWithSigner.swapToLightningNetwork(amount * 10 ** 10, invoice.paymentRequest, { value: amount * 10 ** 10 });
        console.log("Transaction sent:", tx.hash);
        setMessage(`Tx sent: ${tx.hash}`);
        // Wait for the transaction to be mined
        await tx.wait();
        setMessage(`Tx confirmed: ${tx.hash} calling service to pay invoice`);
        // Do eth tx and then call main.payInvoicesAccordingToEvents();
        resp = await main.payInvoicesAccordingToEvents();
      } else {
        //resp = await main.payInvoicesAccordingToEvents(invoicePay);
      }
      setMessage(resp);
    } catch (err) {
      setMessage(err.message)
    }
  };
  const checkInvoice = async () => {
    try {
      const resp = await main.swapFromLightningNetwork(r_hash.replace(/\+/g, '-').replace(/\//g, '_'));
      setMessage(resp);
    } catch (err) {
      setMessage(err.message)
    }
  }

  const claimRBTC = useCallback(async () => {
    if (provider && bridge) {
      setMessage("Confirm transaction to claim");
      const signer = await provider.getSigner();
      const bridgeWithSigner = bridge.connect(signer);
      const tx = await bridgeWithSigner.claimRBTC();
      setMessage(`RBTC claimed: ${tx.hash}`);
      await tx.wait();
    }
  }, [provider, bridge]);

  // UI Rendering


  const renderRSKToLight = () => (
    <div>
      {/* Content for RSK to Lightning */}

      <div className={styles.step}>
        <p>Step 1: Create an invoice that will be paid by the Bridge, (you will be prompted to confirm the transaction sending RBTC on RSK)</p>
        <label className={styles.label}>Amount (satoshi)</label>
        <input
          className={styles.input}
          value={amount}
          onChange={(ev) => setAmount(ev.target.value)}
          placeholder="Enter amount"
        />
        <label className={styles.label}>Description</label>
        <input
          className={styles.input}
          value={memo}
          onChange={(ev) => setMemo(ev.target.value)}
          placeholder="Enter Description (optional)"
        />
        {
          !coinbase ?
            <button className={styles.button} onClick={loadWeb3Modal}>Connect Wallet</button> :
            <button className={styles.button} onClick={sendInvoiceAndRBTC}>Send Invoice!</button>
        }
      </div>
    </div>
  );

  const renderLightToRSK = () => (
    <div>
      {/* Content for Lightning to RSK */}
      <div className={styles.step}>
        <p>Step 1: Request an invoice to swap to RSK</p>
        <label className={styles.label}>Amount (satoshi)</label>
        <input
          className={styles.input}
          value={amount}
          onChange={(ev) => setAmount(ev.target.value)}
          placeholder="Enter amount"
        />
        <label className={styles.label}>RSK EVM Recipient Address</label>
        <input
          className={styles.input}
          value={evm_address}
          onChange={(ev) => setEvmAddr(ev.target.value)}
          placeholder="Enter EVM address"
        />
        <button className={styles.button} onClick={getInvoice}>Get Invoice!</button>
      </div>
      <div className={styles.step}>
        <p>Step 2: Input r_hash from the invoice generated by the service after you pay it</p>
        <input
          className={styles.input}
          value={r_hash}
          onChange={(ev) => setPaymentHash(ev.target.value)}
          placeholder="Enter r_hash"
        />
        <button className={styles.button} onClick={checkInvoice}>Check Invoice!</button>
      </div>
      <div className={styles.step}>
        <h3>Claim RBTC If you have been already bridged to RSK</h3>
        {
          !coinbase ?
            <button className={styles.button} onClick={loadWeb3Modal}>Connect Wallet</button> :
            bridge && <button className={styles.button} onClick={claimRBTC}>Claim RBTC</button>
        }
      </div>
    </div>
  );

  const renderNostrEvents = () => (
    <div>
      {/* Content for nostr messages */}
      <h3>Invoices paid by service</h3>
      <p><a href={`https://iris.to/${npub}`} target="_blank">See at iris.to</a></p>
      {
        events.map(e => {

          return (
            <div key={e.id} className={styles.step} style={{ overflowX: "auto" }}>
              <div>{new Date(e.created_at * 1000).toString()}</div>
              <div>{e.content}</div>
            </div>
          )
        })
      }
    </div>
  );


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

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <p>Welcome to RSK Lightning Bridge!</p>
        <p>Follow the steps below to bridge your assets.</p>
      </div>

      {
        coinbase && bridge &&
        <div className={styles.balance}>
          <p>EVM connected as {coinbase}</p>
          <p>Your RSK Balance: {userBalance}</p>
        </div>
      }
      <div className={styles.tabs}>
        <button
          className={activeTab === 'rskToLight' ? styles.activeTab : ''}
          onClick={() => setActiveTab('rskToLight')}
        >
          RSK to Lightning
        </button>
        <button
          className={activeTab === 'lightToRSK' ? styles.activeTab : ''}
          onClick={() => setActiveTab('lightToRSK')}
        >
          Lightning to RSK
        </button>
        <button
          className={activeTab === 'nostrEvents' ? styles.activeTab : ''}
          onClick={() => setActiveTab('nostrEvents')}
        >
          Nostr Events
        </button>
      </div>

      {activeTab === 'rskToLight' ? renderRSKToLight() : activeTab === 'lightToRSK' ? renderLightToRSK() : renderNostrEvents()}


      <div>
        <span className={styles.message}>{message}</span>
      </div>
    </div>
  );

};

render(<RSKLightningBridge />, document.getElementById("app"));
