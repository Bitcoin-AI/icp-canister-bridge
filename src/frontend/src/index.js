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
  const [userInvoice,setUserInvoice] = useState();
  const [nodeInfo,setNodeInfo] = useState();
  const [processing,setProcessing] = useState();

  const [chains,setChains] = useState([]);
  const [chain,setChain] = useState();
  const [canisterAddr,setCanisterAddr] = useState();
  const [evm_txHash,setEvmTxHash] = useState();

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


  const base64UrlEncode = (input) => {
    let base64 = Buffer.from(input, 'hex').toString('base64');
    let base64Url = base64.replace(/\+/g, '-').replace(/\//g, '_');
    return base64Url;
  };

  const getInvoice = async () => {
    setProcessing(true);
    try {
      setMessage("Getting invoice from service");
      const resp = await main.generateInvoiceToSwapToRsk(Number(amount), evm_address.replace("0x", ""),new Date().getTime().toString());
      setMessage(resp);
      console.log(JSON.parse(resp))
      const invoice = JSON.parse(resp).payment_request;
      const base64PaymentHash = JSON.parse(resp).r_hash;
      setPaymentHash(base64PaymentHash);
      const r_hashUrl = base64PaymentHash.replace(/\+/g, '-').replace(/\//g, '_');
      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        setMessage(`Pay invoice ${invoice}`);
        const result = await window.webln.sendPayment(invoice);
        setMessage("Invoice paid, wait for service send evm transaction ...");
        const invoiceCheckResp = await main.swapLN2EVM(ethers.toBeHex(JSON.parse(chain).chainId),r_hashUrl,new Date().getTime().toString());
        console.log(invoiceCheckResp);
        setMessage(invoiceCheckResp);
      } else {
        setMessage(`Pay invoice: ${invoice} and go step2: checkInvoice with payment hash: ${r_hashUrl}`)
      }
      setProcessing(false);
    } catch (err) {
      setMessage(`${err.message}`);
    }
    setProcessing(false);

  }

  const checkInvoice = async () => {
    setProcessing(true);
    try {
      setMessage("Processing evm transaction ...")
      const resp = await main.swapLN2EVM(ethers.toBeHex(JSON.parse(chain).chainId),r_hash.replace(/\+/g, '-').replace(/\//g, '_'),new Date().getTime().toString());
      //const parsed = JSON.parse(resp);
      setMessage(resp);
    } catch (err) {
      setMessage(`${err.message}`)
    }
    setProcessing(false);
  }


  const sendToken = async () => {
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
      const tx = await signer.sendTransaction({
          to: `0x${canisterAddr}`,
          value: ethers.parseUnits(amount.toString(),10)
      });
      console.log("Transaction sent:", tx.hash);
      // Use explorers based on chainlist
      setMessage(<>Tx sent: <a href={`https://explorer.testnet.rsk.co/tx/${tx.hash}`} target="_blank">{tx.hash}</a></>);
      // Wait for the transaction to be mined
      await tx.wait();
      setMessage(<>Tx confirmed: <a href={`https://explorer.testnet.rsk.co/tx/${tx.hash}`} target="_blank">{tx.hash}</a>, generate invoice and ask payment</>);
      setEvmTxHash(tx.hash);

      setTimeout(() => {
        setMessage()
      },5000);
    } catch(err){
      console.log(err)
      setMessage(err.message);
      setTimeout(() => {
        setMessage()
      },5000);
    }
  }
  const sendTxHash = async () => {
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
      //const signature = await signer.sign(`\x19Ethereum Signed Message:\n${transaction.hash}`);
      setMessage("Sign transaction hash");
      //const signature = await signer.sign(transaction.hash);
      //const hashedMsg = ethers.hashMessage(`\x19Ethereum Signed Message:\ntest`)
      const signature = await signer.signMessage("test");
      console.log(signature)
      // Do eth tx and then call main.payInvoicesAccordingToEvents();
      //resp = await main.payInvoicesAccordingToEvents(new Date().getTime().toString());
      setMessage("Verifying parameters to process evm payment");
      resp = await main.swapEVM2EVM(
        {
          proofTxId: transaction.hash,
          invoiceId: "null",
          sendingChain: ethers.toBeHex(netId),
          recipientChain: ethers.toBeHex(JSON.parse(chain).chainId),
          recipientAddress: evm_address,
          signature: signature
        }
      );
      setMessage("Service processing evm payment");
      setTimeout(() => {
        setMessage()
      },5000);
    } catch (err) {
      setMessage(err.message);
    }
    setProcessing(false);
  };

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

        const sats = Number(transaction.value)/10**10;
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
      //const signature = await signer.sign(transaction.hash);
      //const hashedMsg = ethers.hashMessage(`\x19Ethereum Signed Message:\ntest`)
      const signature = await signer.signMessage("test");
      console.log(signature)
      //resp = await main.payInvoicesAccordingToEvents(new Date().getTime().toString());
      resp = await main.swapEVM2LN(
        {
          proofTxId: transaction.hash,
          invoiceId: paymentRequest,
          sendingChain: ethers.toBeHex(netId),
          recipientChain: ethers.toBeHex(netId),
          recipientAddress: `0x${canisterAddr}`,
          signature: signature
        },
        new Date().getTime().toString()
      );
      setMessage("Service processing lightning payment");
      setTimeout(() => {
        setMessage()
      },5000);
    } catch (err) {
      setMessage(err.message);
    }
    setProcessing(false);
  };

  // UI Rendering


  const renderRSKToLight = () => (
    <div>
      {/* Content for EVM to Lightning */}
      {
        coinbase && netId &&
        <div class={styles.step}>
          <p>ChainId: {netId.toString()}</p>
        </div>
      }
      <div class={styles.step}>
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
            <button className={styles.button} onClick={sendToken} >Send token</button>
        }
      </div>
      <div class={styles.step}>
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
        <button className={styles.button} onClick={sendInvoiceAndTxHash} >Prepare and send invoice</button>
      </div>
      {
        /*
        <div className={styles.step}>
          <p>Create an invoice that will be paid by the Bridge (you will be prompted to confirm the transaction sending RBTC on RSK)</p>
          {
            typeof(window.webln) !== 'undefined' ?
            <>
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
            </> :
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
            !coinbase ?
              <button className={styles.button} onClick={loadWeb3Modal}>Connect Wallet</button> :
              !processing ?
              <button className={styles.button} onClick={sendInvoiceAndRBTC} >Send Invoice!</button> :
              <button className={styles.button} onClick={sendInvoiceAndRBTC} >Send Invoice!</button>
          }
        </div>
        */
      }
    </div>
  );

  const renderLightToRSK = () => (
    <div>
      {/* Content for Lightning to RSK */}
      <div className={styles.step}>
        <p>Step 1: Request an invoice to swap to EVM compatible chain</p>
        <label className={styles.label}>Amount (satoshi)</label>
        <input
          className={styles.input}
          value={amount}
          onChange={(ev) => setAmount(ev.target.value)}
          placeholder="Enter amount"
        />
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
            return(<option value={JSON.stringify(
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
        {
        !processing ?
        <button className={styles.button} onClick={getInvoice}>Get Invoice!</button> :
        <button className={styles.button} onClick={getInvoice} disabled>Wait current process</button>
        }

      </div>
      <div className={styles.step}>
        <p>Step 2 {typeof(window.webln) !== 'undefined' && '(Optional)'}: Input r_hash from the invoice generated by the service after you pay it</p>
        <input
          className={styles.input}
          value={r_hash}
          onChange={(ev) => setPaymentHash(ev.target.value)}
          placeholder="Enter r_hash"
        />
        {
          !processing ?
          <button className={styles.button} onClick={checkInvoice}>Check Invoice!</button>:
          <button className={styles.button} onClick={checkInvoice} disabled>Wait current process</button>

        }
      </div>
      {
        /*
        <div className={styles.step}>
          <h3>Claim RBTC If you have been already bridged to RSK</h3>
          {
            !coinbase ?
              <button className={styles.button} onClick={loadWeb3Modal}>Connect Wallet</button> :
              !processing && bridge ?
               <button className={styles.button} onClick={claimRBTC}>Claim RBTC</button> :
               <button className={styles.button} onClick={claimRBTC} disabled>Wait current process</button>
          }
        </div>
        */
      }
    </div>
  );

  const renderEVM2EVM = () => (
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
            return(<option value={JSON.stringify(
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
            <button className={styles.button} onClick={sendToken} >Send token</button>
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
        <button className={styles.button} onClick={sendTxHash}>Finalize swap</button>
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
        coinbase && bridge &&
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
            setMessage();
          }}
        >
          EVM to Lightning
        </button>
        <button
          className={activeTab === 'lightToRSK' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('lightToRSK');
            setMessage();
          }}
        >
          Lightning to EVM
        </button>
        <button
          className={activeTab === 'evmToEvm' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('evmToEvm');
            setMessage();
          }}
        >
          EVM to EVM
        </button>
        <button
          className={activeTab === 'nostrEvents' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('nostrEvents');
            setMessage();
          }}
        >
          Nostr Events
        </button>
      </div>

      {
        activeTab === 'rskToLight' ?
        renderRSKToLight() :
        activeTab === 'lightToRSK' ?
        renderLightToRSK() :
        activeTab==='evmToEvm'? renderEVM2EVM() :
        renderNostrEvents()
      }


      <div style={{overflowX: "auto"}}>
        <span className={styles.message}>{message}</span>
      </div>
    </div>
  );

};

render(<RSKLightningBridge />, document.getElementById("app"));
