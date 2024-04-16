import React, { useState,useEffect,useRef } from "react";
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faPencilAlt, faCheck } from '@fortawesome/free-solid-svg-icons';
import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json';
import { main } from "../../../declarations/main";
import styles from '../RSKLightningBridge.module.css';  // Import the CSS module
const Petitions = ({
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


  const [solve,setSolvePetition] = useState(false);
  const petitionToSolve = useRef();
  const [petitions,setPetitions] = useState([]);
  const [EXPLORER_BASEURL,setExplorerBaseUrl] = useState("https://explorer.testnet.rsk.co/tx/");


  const fetchPetitions = async () => {
    try {
      const mainPetitions = await main.getPetitions();
      console.log(mainPetitions)
      let newPetitions = [];
      for(let mainPetition of mainPetitions){
        try{
          const sendingChain = chains.filter(item => item.chainId === Number(mainPetition.sendingChain))[0];
          console.log(sendingChain)
          const jsonRpcProvider = new ethers.JsonRpcProvider(sendingChain.rpc[0]);
          const transaction = await jsonRpcProvider.getTransaction(mainPetition.proofTxId);
          console.log(transaction)
          mainPetition.transaction = transaction;
          newPetitions.push(mainPetition);
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
      // Do eth tx and then call main.payInvoicesAccordingToEvents();
      //resp = await main.payInvoicesAccordingToEvents(new Date().getTime().toString());
      setMessage("Verifying parameters to process petition request");
      if(solve){
        resp = await main.solvePetitionEVM2EVM(
          petitionToSolve.current.transaction.hash,
          transaction.hash,
          signature
        );
      } else {
        const wbtcAddressWanted = chains.filter(item => {return item.chainId === Number(JSON.parse(chain).chainId)})[0].wbtcAddress;
        const wbtcAddressSent = chains.filter(item => {return item.chainId === Number(netId)})[0].wbtcAddress;
        resp = await main.petitionEVM2EVM(
          {
            proofTxId: transaction.hash,
            invoiceId: "0",
            petitionPaidInvoice: "0",
            sendingChain: ethers.toBeHex(netId),
            wantedChain: ethers.toBeHex(JSON.parse(chain).chainId),
            wantedAddress: evm_address.toLowerCase(),
            signature: signature,
            reward: '0',
            wbtc: wbtcAddressSent ? true : false,
            wantedERC20: wbtcAddressWanted ? wbtcAddressWanted : "0",
            sentERC: wbtcAddressSent ? wbtcAddressSent : "0"
          }
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
        setMessage(<>Tx sent: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a></>);
        // Wait for the transaction to be mined
        await tx.wait();
        setMessage(<>Tx confirmed: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a>, finalize petition</>);
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
      <FontAwesomeIcon icon={faPencilAlt} /> Create Petitions
    </button>
    <button
      className={solve ? styles.activeTab : ''}
      onClick={() => {
        setSolvePetition(true);
      }}
    >
      <FontAwesomeIcon icon={faCheck} /> Solve Petitions
    </button>
  </div>
  {
    !solve ?
    <div className={styles.container}>
      {/* Content for Petitions */}
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
            const filteredRpc = item.rpc.filter(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}"));
            if (filteredRpc.length > 0) {
              return (
                <option value={JSON.stringify({
                  rpc: filteredRpc[0].toString(),
                  chainId: item.chainId,
                  name: item.name
                })}>{item.name}</option>
              );
            } else {
              return null;
            }
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
      <div className={styles.step}>
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
          <button className={styles.button} onClick={() => {sendToken(solve);}} >Send token</button> :
          <button className={styles.button} disabled >Wait current process</button>
        }
      </div>
      {
        coinbase && netId &&
        <div className={styles.step}>
          <p>Sending from chainId {netId.toString()}</p>
        </div>
      }
    </div> :
    <div className={styles.container}>
      <div className={styles.step}>
        <h2>Petitions</h2>
        {
          petitions.map(item => {
            if(Number(netId) !== Number(item.wantedChain)) return;
            if(item.sendingChain === "0" || item.wantedChain === "0") return;
            return(
              <div key={item.proofTxId}>
                <p>From chain: {item.sendingChain}</p>
                <p>To chain: {item.wantedChain}</p>
                {
                  item.sendingChain === "0x1f" ?
                  <p>Amount: {(Number(item.transaction.value)/10**10)?.toString()} satoshis of rbtc</p> :
                  <p>Amount: {(Number(`0x${item.transaction.data.slice(74).replace(/^0+/, '')}`)/10**10).toString()} satoshis of wbtc</p> 
                }
                <p>Reward: {item.reward}</p>
                {
                  petitionToSolve.current &&
                  (
                    JSON.stringify(petitionToSolve.current) === JSON.stringify(item) &&
                    <p><b>Petition Selected</b></p>
                  )
                }
                <button className={styles.button} onClick={async () => {
                    petitionToSolve.current = item;
                    sendToken(solve);
                  }}>Initiate petition solving</button>
                {
                  !petitionToSolve.current &&
                  <button className={styles.button} onClick={async () => {
                    petitionToSolve.current = item;
                  }}>Select Petition</button>
                }
              </div>
            );
          })
        }
      </div>
    </div>

  }
  <div className={styles.container}>
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
  </div>
  <div style={{overflowX: "auto"}}>
        <span className={styles.message}>{message}</span>
  </div>
  </>
  );
};
export default Petitions;
