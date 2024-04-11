import React, { useState,useEffect,useRef } from "react";

import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json';
import { main } from "../../../declarations/main";
import styles from '../RSKLightningBridge.module.css';  // Import the CSS module
const PetitionsLN = ({
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


  const [ln,setLN] = useState(false);


  const [r_hash, setPaymentHash] = useState('');
  const [solve,setSolvePetition] = useState(false);
  const petitionToSolve = useRef();
  const [petitions,setPetitions] = useState([]);

  // Function to decode ERC20 transfer transaction
  const decodeERC20Transfer = async (txInput) => {
    const iface = new ethers.Interface(ERC20ABI);
    const decodedInput = await iface.parseTransaction({ data: txInput });
    console.log(`Tx decoded`);
    console.log(decodedInput);
    return decodedInput.args;
  }

  const fetchPetitions = async () => {
    try {
      const mainPetitions = await main.getPetitions();
      console.log(mainPetitions)
      let newPetitions = [];
      for(let mainPetition of mainPetitions){
        try{
          if(mainPetition.proofTxId == "0"){
            mainPetition.transaction = {
              data: ""
            }
            newPetitions.push(mainPetition);
          } else {
            const wantedChain = chains.filter(item => item.chainId === Number(netId))[0];
            console.log(wantedChain)
            const jsonRpcProvider = new ethers.JsonRpcProvider(wantedChain.rpc[0]);
            const transaction = await jsonRpcProvider.getTransaction(mainPetition.proofTxId);
            console.log(transaction)
            mainPetition.transaction = transaction;
            newPetitions.push(mainPetition);
          }

        } catch(err){
          console.log(mainPetition)
        }
      }
      setPetitions(newPetitions);
      console.log('Petitions:', newPetitions);
    } catch (error) {
      console.error('Failed to fetch petitions:', error);
    }
  }
  const sendPetitionTxHash = async (solve) => {
    setProcessing(true);
    try {
      let resp;
      const signer = await provider.getSigner();
      setMessage("Prepare invoice to be paid by service");
      const transaction = await provider.getTransaction(evm_txHash);
      console.log(transaction);
      if(!transaction){
        setMessage(`No transaction found`);
        setTimeout(() => {
          setMessage();
        },5000);
        return;
      }
      let invoiceId;
      let sats;

      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        if(netId === 31){
          sats = Number(transaction.value)/10**10
        } else {
          const decodedTxArgs = await decodeERC20Transfer(transaction.data);
          console.log('Decoded transaction:', decodedTxArgs);

          sats = Number(decodedTxArgs[1])/10**10
        };
        invoiceId = await webln.makeInvoice({
          amount: sats,
          defaultMemo: `Chain ${ethers.toBeHex(netId)} - Tx Hash ${transaction.hash}`
        });
        setMessage(`Sending invoice ${invoiceId.paymentRequest}`);
      } else {
        setMessage(`Pay invoice: ${invoiceId.paymentRequest} and go step2: checkInvoice with payment hash: ${r_hashUrl}`)
      }

      //const signature = await signer.sign(`\x19Ethereum Signed Message:\n${transaction.hash}`);
      setMessage("Sign transaction hash");
      //const signature = await signer.sign(transaction.hash);
      //const hashedMsg = ethers.hashMessage(`\x19Ethereum Signed Message:\ntest`)
      const signature = await signer.signMessage(transaction.hash);
      // Do eth tx and then call main.payInvoicesAccordingToEvents();
      //resp = await main.payInvoicesAccordingToEvents(new Date().getTime().toString());
      setMessage("Verifying parameters to process evm payment");
      if(solve){
        resp = await main.solvePetitionEVM2EVM(
          petitionToSolve.current.transaction.hash,
          transaction.hash,
          signature
        );
      } else {
        const wbtcAddressSent = chains.filter(item => {return item.chainId === Number(netId)})[0].wbtcAddress;
        console.log(          {
          proofTxId: transaction.hash,
          invoiceId: invoiceId.paymentRequest,
          sendingChain: ethers.toBeHex(netId),
          wantedChain: "0",
          wantedAddress: "0",
          signature: signature,
          reward: '0',
          wbtc: false,
          wantedERC20: "0",
          sentERC: wbtcAddressSent ? wbtcAddressSent : "0"
        })
        resp = await main.petitionEVM2LN(
          {
            proofTxId: transaction.hash,
            invoiceId: invoiceId.paymentRequest,
            sendingChain: ethers.toBeHex(netId),
            wantedChain: "0",
            wantedAddress: "0",
            signature: signature,
            reward: '0',
            wbtc: wbtcAddressSent ? true : false,
            wantedERC20: "0",
            sentERC: wbtcAddressSent ? wbtcAddressSent : "0"
          },
          new Date().getTime().toString()
        );
        setTimeout(() => {
          fetchPetitions();
        },1000);
      }
      setMessage(resp);
    } catch (err) {
      setMessage(err.message);
    }
    setProcessing(false);
  };

  const sendToken = async (solve) => {
      setProcessing(true);
      try{
        // Send the transaction
        if(!provider){
          await loadWeb3Modal();
        }
        const signer = await provider.getSigner();

        if(solve && !(Number(petitionToSolve.current.wantedChain) === Number(netId))){
          alert("Wrong network");
          return
        }
        //const bridgeWithSigner = bridge.connect(signer);
        setMessage(`Sending token to ${solve ? petitionToSolve.current.wantedAddress : `0x${canisterAddr}`}`);
        //const tx = await bridgeWithSigner.swapToLightningNetwork(amount * 10 ** 10, paymentRequest, { value: amount * 10 ** 10 });
        // Change for wbtc or rsk transaction based on ChainId
        let tx;
        let value;
        if(solve){
          value = petitionToSolve.current.transaction.value;
          if(petitionToSolve.current.sentERC !== "0"){
            value = `0x${petitionToSolve.current.transaction.data.slice(74).replace(/^0+/, '')}`
          };
          console.log(petitionToSolve.current.transaction.data)
        }
        if(Number(netId) === 31){
          tx = await signer.sendTransaction({
            to: solve ? petitionToSolve.current.wantedAddress : `0x${canisterAddr}`,
            value: solve ? (value).toString() : ethers.parseUnits(amount.toString(),10)
          });
        } else {
          // Connect contract and do transaction;
          const wbtcAddress = chains.filter(item => {return item.chainId === Number(netId)})[0].wbtcAddress;
          const tokenContract = new ethers.Contract(wbtcAddress, ERC20ABI, signer);
          tx = await tokenContract.transfer(
            solve ? petitionToSolve.current.wantedAddress : `0x${canisterAddr}`,
            solve ? (value).toString() : ethers.parseUnits(amount.toString(),10)
          );
        }
        console.log("Transaction sent:", tx.hash);
        // Use explorers based on chainlist
        setMessage(<>Tx sent: <a href={`https://explorer.testnet.rsk.co/tx/${tx.hash}`} target="_blank">{tx.hash}</a></>);
        // Wait for the transaction to be mined
        await tx.wait();
        setAmount(ethers.parseUnits(amount.toString(),18));
        setMessage(<>Tx confirmed: <a href={`https://explorer.testnet.rsk.co/tx/${tx.hash}`} target="_blank">{tx.hash}</a>, generate invoice and ask payment</>);
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
  const getInvoice = async () => {
    setProcessing(true);
    try {
      setMessage("Getting invoice from service");
      const resp = await main.generateInvoiceToSwapToRsk(Number(amount), evm_address,new Date().getTime().toString());
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
      setMessage("Processing evm transaction ...");
      const wbtcAddressWanted = chains.filter(item => {return item.chainId === Number(JSON.parse(chain).chainId)})[0].wbtcAddress;
      const resp = await main.petitionLN2EVM(
        {
          proofTxId: "0",
          invoiceId: "null",
          sendingChain: "0",
          wantedChain: ethers.toBeHex(JSON.parse(chain).chainId),
          wantedAddress: evm_address.toLowerCase(),
          signature: "0",
          reward: '0',
          wbtc: false,
          wantedERC20: wbtcAddressWanted ? wbtcAddressWanted : "0",
          sentERC: "0"
        },
        r_hash.replace(/\+/g, '-').replace(/\//g, '_'),
        new Date().getTime().toString()
      );
      //const parsed = JSON.parse(resp);
      setMessage(resp);
    } catch (err) {
      setMessage(`${err.message}`)
    }
    setProcessing(false);
  }
  useEffect(() => {
    fetchPetitions();
  },[]);
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
  useEffect(() => {
    if (coinbase) {
      setEvmAddr(coinbase);
    }
  }, [coinbase]);
  return(
  <>
  <div className={styles.tabs}>
    <button
        className={!solve ? styles.activeTab : ''}
        onClick={() => {
          setSolvePetition(false);
        }}
      >
        Create Petitions
      </button>
      <button
        className={solve ? styles.activeTab : ''}
        onClick={() => {
          setSolvePetition(true);
        }}
      >
        Solve Petitions
      </button>
  </div>
  {
    !solve ?
    <div className={styles.container}>
      {/* Content for Petitions */}
      <div className={styles.step}>
        <select
            className={styles.input}
            type="select"
            onChange={(ev) => {setLN(!ln)}}
          >
            <option value={false} selected>EVM</option>
            <option value={true}>Lightning</option>
          </select>
      </div>
      {
        !ln ?
        <>
        <div className={styles.step}>
          <p>Send token to 0x{canisterAddr}</p>
          <p>Sending from chainId {netId?.toString()}</p>
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
            <button className={styles.button} onClick={() => {sendToken(solve);}} >Send token</button> :
            <button className={styles.button} disabled >Wait current process</button>
          }
        </div>
        <div className={styles.step}>
            <p>Input evm transaction hash</p>
            <label className={styles.label}>Transaction Hash</label>
            <input
              className={styles.input}
              value={evm_txHash}
              onChange={(ev) => setEvmTxHash(ev.target.value)}
              placeholder="Transaction Hash"
            />
        </div>
        <div className={styles.step}>
        {
          !processing ?
          <button className={styles.button} onClick={() => {sendPetitionTxHash(solve);}}>Finalize petition</button> :
          <button className={styles.button} disabled >Wait current process</button>
        }
        </div>
        </> : 
        <>
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
        </>
      }
    </div> :
    <div className={styles.container}>
      <div className={styles.step}>
        <h2>Petitions</h2>
        {
          petitions.map(item => {
            //if(Number(netId) !== Number(item.wantedChain)) return;
            return(
              <div>
                <p>From: {item.sendingChain !== "0" ? item.sendingChain : item.sendingChain}</p>
                <p>To: {item.wantedChain !== "0" ? item.wantedChain : "Bitcoin Lightning Network"}</p>
                {
                  item.proofTxId === "0" ?
                    item.sendingChain === "0x1f" ?
                    <p>Amount: {(item.transaction?.value)?.toString()}</p> :
                    <p>Amount: {Number(`0x${item.transaction.data.slice(74).replace(/^0+/, '')}`)}</p> :
                  <p style={{overflowX: 'auto'}}>{item.invoiceId}</p>
                }
                <p>Reward: {item.reward}</p>
                <button className={styles.button} onClick={async () => {
                    petitionToSolve.current = item;
                    if(item.invoiceId.indexOf("lntb") !== -1){
                      //sendToken(solve);
                    } else {
                      sendToken(solve);
                    };
                    return;
                  }}>Initiate petition solving</button>
                <button className={styles.button} onClick={async () => {
                    petitionToSolve.current = item;
                  }}>Select Petition</button>
              </div>
            );
          })
        }
      </div>
    </div>

  }
  <div style={{overflowX: "auto"}}>
        <span className={styles.message}>{message}</span>
  </div>
  </>
  );
};
export default PetitionsLN;
