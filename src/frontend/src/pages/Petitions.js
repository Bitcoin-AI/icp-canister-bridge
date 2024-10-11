import React, { useState, useEffect, useRef } from "react";
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faPencilAlt, faCheck } from '@fortawesome/free-solid-svg-icons';
import { ethers } from 'ethers';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json';
import { main } from "../../../declarations/main";

const Petitions = ({
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
  const [solve, setSolvePetition] = useState(false);
  const petitionToSolve = useRef();
  const [petitions, setPetitions] = useState([]);
  const [EXPLORER_BASEURL, setExplorerBaseUrl] = useState("https://explorer.testnet.rsk.co/tx/");

  const fetchPetitions = async () => {
    try {
      const mainPetitions = await main.getPetitions();
      let newPetitions = [];
      for (let mainPetition of mainPetitions) {
        try {
          const sendingChain = chains.filter(item => item.chainId === Number(mainPetition.sendingChain))[0];
          const jsonRpcProvider = new ethers.JsonRpcProvider(sendingChain.rpc[0]);
          const transaction = await jsonRpcProvider.getTransaction(mainPetition.proofTxId);
          mainPetition.transaction = transaction;
          newPetitions.push(mainPetition);
        } catch (err) {
          console.log(mainPetition);
        }
      }
      setPetitions(newPetitions);
    } catch (error) {
      console.error('Failed to fetch petitions:', error);
    }
  }

  const sendPetitionTxHash = async (solve) => {
    setProcessing(true);
    try {
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
      setMessage("Verifying parameters to process petition request");
      let resp;
      if (solve) {
        resp = await main.solvePetitionEVM2EVM(
          petitionToSolve.current.transaction.hash,
          transaction.hash,
          signature
        );
      } else {
        const wbtcAddressWanted = chains.filter(item => item.chainId === Number(JSON.parse(chain).chainId))[0].wbtcAddress;
        const wbtcAddressSent = chains.filter(item => item.chainId === Number(netId))[0].wbtcAddress;
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
        }, 1000);
      }
      setMessage(resp);
    } catch (err) {
      setMessage(err.message);
    }
    setProcessing(false);
  };

  const sendToken = async (solve) => {
    setProcessing(true);
    try {
      if (!provider) {
        await loadWeb3Modal();
      }
      const signer = await provider.getSigner();
      if (solve && !(Number(petitionToSolve.current.wantedChain) === Number(netId))) {
        alert("Wrong network");
        return;
      }
      setMessage(`Sending token to ${`0x${canisterAddr}`}`);
      let tx;
      let value;
      if (solve) {
        value = petitionToSolve.current.transaction.value;
        if (petitionToSolve.current.sentERC !== "0") {
          value = `0x${petitionToSolve.current.transaction.data.slice(74).replace(/^0+/, '')}`;
        }
      }
      if (Number(netId) === 31) {
        tx = await signer.sendTransaction({
          to: `0x${canisterAddr}`,
          value: solve ? (value).toString() : ethers.parseUnits(amount.toString(), 10)
        });
      } else {
        const wbtcAddress = chains.filter(item => item.chainId === Number(netId))[0].wbtcAddress;
        const tokenContract = new ethers.Contract(wbtcAddress, ERC20ABI, signer);
        tx = await tokenContract.transfer(
          `0x${canisterAddr}`,
          solve ? (value).toString() : ethers.parseUnits(amount.toString(), 10)
        );
      }
      console.log("Transaction sent:", tx.hash);
      setMessage(<>Tx sent: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a></>);
      await tx.wait();
      setMessage(<>Tx confirmed: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a>, finalize petition</>);
      setEvmTxHash(tx.hash);
    } catch (err) {
      console.log(err);
      setMessage(err.message);
      setTimeout(() => {
        setMessage();
      }, 5000);
    }
    setProcessing(false);
  };

  useEffect(() => {
    fetchPetitions();
  }, []);

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

  useEffect(() => {
    if (coinbase) {
      setEvmAddr(coinbase);
    }
  }, [coinbase]);

  return (
    <div className="flex-grow max-w-3xl mx-auto p-4">
      <h1 className="text-2xl font-bold text-center mb-6">Petitions</h1>

      <div className="flex space-x-4 mb-6">
        <button
          className={`w-1/2 p-2 rounded ${!solve ? 'bg-blue-500 text-white' : 'bg-gray-300'}`}
          onClick={() => {
            setSolvePetition(false);
          }}
        >
          <FontAwesomeIcon icon={faPencilAlt} /> Create Petitions
        </button>
        <button
          className={`w-1/2 p-2 rounded ${solve ? 'bg-blue-500 text-white' : 'bg-gray-300'}`}
          onClick={() => {
            setSolvePetition(true);
          }}
        >
          <FontAwesomeIcon icon={faCheck} /> Solve Petitions
        </button>
      </div>

      {
        !solve ?
          <div className="mb-6">
            <div className="mb-4">
              <p>Step 1: Select recipient and EVM compatible chain</p>
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
            <div className="mb-4">
              <p>Step 2: Send token to 0x{canisterAddr}</p>
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
                    <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={() => { sendToken(solve); }}>Send token</button> :
                    <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" disabled>Wait current process</button>
              }
            </div>
            {
              coinbase && netId &&
              <div className="mb-4">
                <p>Sending from chainId {netId.toString()}</p>
              </div>
            }
          </div> :
          <div className="mb-6">
            <div className="mb-4">
              <h2>Petitions</h2>
              {
                petitions.map(item => {
                  if (Number(netId) !== Number(item.wantedChain)) return;
                  if (item.sendingChain === "0" || item.wantedChain === "0") return;
                  return (
                    <div key={item.proofTxId} className="mb-4">
                      <p>From chain: {item.sendingChain}</p>
                      <p>To chain: {item.wantedChain}</p>
                      {
                        item.sendingChain === "0x1f" ?
                          <p>Amount: {(Number(item.transaction.value) / 10 ** 10)?.toString()} satoshis of rbtc</p> :
                          <p>Amount: {(Number(`0x${item.transaction.data.slice(74).replace(/^0+/, '')}`) / 10 ** 10).toString()} satoshis of wbtc</p>
                      }
                      <p>Reward: {item.reward}</p>
                      {
                        petitionToSolve.current &&
                        (
                          JSON.stringify(petitionToSolve.current) === JSON.stringify(item) &&
                          <p><b>Petition Selected</b></p>
                        )
                      }
                      <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={async () => {
                        petitionToSolve.current = item;
                        sendToken(solve);
                      }}>Initiate petition solving</button>
                      {
                        !petitionToSolve.current &&
                        <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={async () => {
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

      <div className="mb-6">
        <div className="mb-4">
          <p>Input evm transaction hash</p>
          <label className="block mb-2">Transaction Hash</label>
          <input
            className="w-full p-2 border border-gray-300 rounded mb-4"
            value={evm_txHash}
            onChange={(ev) => setEvmTxHash(ev.target.value)}
            placeholder="Transaction Hash"
          />
        </div>
        <div className="mb-4">
          {
            !processing ?
              <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={() => { sendPetitionTxHash(solve); }}>Finalize petition</button> :
              <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" disabled>Wait current process</button>
          }
        </div>
      </div>

      {message && (
        <div className="p-3 rounded mt-3 break-all bg-blue-100 text-blue-700">
          {message}
        </div>
      )}
    </div>
  );
};

export default Petitions;