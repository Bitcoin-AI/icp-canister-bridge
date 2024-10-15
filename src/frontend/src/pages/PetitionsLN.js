import React, { useState, useEffect, useRef } from "react";
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faPencilAlt, faCheck } from '@fortawesome/free-solid-svg-icons';
import { ethers } from 'ethers';
import { decode } from 'light-bolt11-decoder';
import ERC20ABI from '../../assets/contracts/abis/erc20Abi.json';
import { main } from "../../../declarations/main";

import CreatePetitionLN from '../components/petitions/CreatePetitionLN';
import SolvePetitionsLN from '../components/petitions/SolvePetitionsLN';


const PetitionsLN = ({
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
  const [currentPetitionToSolve, setCurrentPetitionToSolve] = useState(null);
  const [ln, setLN] = useState(false);
  const [petitionPaidInvoice, setPetitionPaidInvoice] = useState();
  const [petitionSolveInvoice, setPetitionSolveInvoice] = useState();
  const [r_hash, setPaymentHash] = useState('');
  const [solve, setSolvePetition] = useState(false);
  const petitionToSolve = useRef();
  const [petitions, setPetitions] = useState([]);
  const [EXPLORER_BASEURL, setExplorerBaseUrl] = useState("https://explorer.testnet.rsk.co/tx/");

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
      let newPetitions = [];
      for (let mainPetition of mainPetitions) {
        try {
          if (mainPetition.proofTxId == "0" && mainPetition.petitionPaidInvoice.indexOf('lntb') !== -1) {
            mainPetition.transaction = {
              data: ""
            }
            let decodedPetitionPaidInvoice = decode(mainPetition.petitionPaidInvoice);
            mainPetition.decodedPetitionPaidInvoice = decodedPetitionPaidInvoice;
            newPetitions.push(mainPetition);
          } else {
            const wantedChain = chains.filter(item => item.chainId === Number(netId))[0];
            const jsonRpcProvider = new ethers.JsonRpcProvider(wantedChain.rpc[0]);
            const transaction = await jsonRpcProvider.getTransaction(mainPetition.proofTxId);
            mainPetition.transaction = transaction;
            newPetitions.push(mainPetition);
          }
        } catch (err) {
          console.log(mainPetition);
        }
      }
      setPetitions(newPetitions);
    } catch (error) {
      console.error('Failed to fetch petitions:', error);
    }
  }

  const sendPetitionTxHash = async () => {
    setProcessing(true);
    try {
      const signer = await provider.getSigner();
      setMessage("Prepare invoice to be paid by service");
      const transaction = await provider.getTransaction(evm_txHash);
      if (!transaction) {
        setMessage(`No transaction found`);
        setTimeout(() => {
          setMessage();
        }, 5000);
        return;
      }
      let invoiceId;
      let sats;
      const signature = await signer.signMessage(transaction.hash);
      if (Number(netId) === 31) {
        sats = Number(transaction.value) / 10 ** 10
      } else {
        const decodedTxArgs = await decodeERC20Transfer(transaction.data);
        sats = Number(decodedTxArgs[1]) / 10 ** 10
      };
      if (solve) {
        setMessage("Solving petition");
        if (typeof window.webln !== 'undefined') {
          await window.webln.enable();
          setMessage("Create invoice to be paid");
          invoiceId = await webln.makeInvoice({
            amount: sats,
            defaultMemo: `Chain ${ethers.toBeHex(netId)} - Tx Hash ${transaction.hash}`
          });
          setPetitionSolveInvoice(invoiceId.paymentRequest);
          setMessage("Verifying parameters to process lightning payment");
          const resp = await main.solvePetitionLN2EVM(
            petitionToSolve.current.petitionPaidInvoice,
            invoiceId.paymentRequest,
            transaction.hash,
            signature,
            new Date().getTime().toString()
          );
          setMessage(resp);
        } else {
          setMessage(`Pay invoice: ${invoiceId.paymentRequest} and go step2: checkInvoice with payment hash: ${r_hashUrl}`)
        }
      } else {
        setMessage("Verifying parameters to add petition");
        if (typeof window.webln !== 'undefined') {
          await window.webln.enable();
          invoiceId = await webln.makeInvoice({
            amount: sats,
            defaultMemo: `Chain ${ethers.toBeHex(netId)} - Tx Hash ${transaction.hash}`
          });
          setMessage(`Sending invoice ${invoiceId.paymentRequest}`);
        } else {
          setMessage(`Pay invoice: ${invoiceId.paymentRequest} and go step2: checkInvoice with payment hash: ${r_hashUrl}`)
        }
        const wbtcAddressSent = chains.filter(item => item.chainId === Number(netId))[0].wbtcAddress;
        const resp = await main.petitionEVM2LN(
          {
            proofTxId: transaction.hash,
            invoiceId: invoiceId.paymentRequest,
            petitionPaidInvoice: "0",
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
        setMessage(resp);
      }
      setTimeout(() => {
        fetchPetitions();
      }, 1000);
      setTimeout(() => {
        setMessage();
      }, 5000);
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
      if (solve && !(Number(petitionToSolve.current.wantedChain) === Number(netId))) {
        setProcessing(false);
        alert("Wrong network");
        return;
      }
      setMessage(`Sending token to ${solve ? petitionToSolve.current.wantedAddress : `0x${canisterAddr}`}`);
      let tx;
      let value;
      if (solve) {
        if (petitionToSolve.current.transaction.value) {
          value = petitionToSolve.current.transaction.value;
        };
        if (petitionToSolve.current.sentERC !== "0") {
          value = `0x${petitionToSolve.current.transaction.data.slice(74).replace(/^0+/, '')}`;
        };
        if (petitionToSolve.current.decodedPetitionPaidInvoice?.sections[2]?.value) {
          value = Number(petitionToSolve.current.decodedPetitionPaidInvoice.sections[2].value) * 10 ** 7;
        };
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
      setMessage(<>Tx confirmed: <a href={`${EXPLORER_BASEURL}${tx.hash}`} target="_blank">{tx.hash}</a>, generate invoice and ask payment</>);
      setEvmTxHash(tx.hash);
    } catch (err) {
      console.log(err);
      setMessage(err.message);
    }
    setTimeout(() => {
      setMessage();
    }, 5000);
    setProcessing(false);
    setTimeout(() => {
      fetchPetitions();
    }, 1000);
  };

  const getInvoice = async () => {
    setProcessing(true);
    try {
      setMessage("Getting invoice from service");
      const resp = await main.generateInvoiceToSwapToRsk(Number(amount), evm_address, new Date().getTime().toString());
      setMessage(resp);
      const invoice = JSON.parse(resp).payment_request;
      setPetitionPaidInvoice(invoice);
      const base64PaymentHash = JSON.parse(resp).r_hash;
      setPaymentHash(base64PaymentHash);
      const r_hashUrl = base64PaymentHash.replace(/\+/g, '-').replace(/\//g, '_');
      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        setMessage(`Pay invoice ${invoice}`);
        const result = await window.webln.sendPayment(invoice);
        setMessage("Invoice paid");
      } else {
        setMessage(`Pay invoice: ${invoice} and go step2: checkInvoice with payment hash: ${r_hashUrl}`)
      }
      setProcessing(false);
    } catch (err) {
      setMessage(`${err.message}`);
    }
    setProcessing(false);
  };

  const payPetitionInvoice = async (amt) => {
    try {
      setMessage("Getting invoice from service");
      const resp = await main.generateInvoiceToSwapToRsk(Number(amt), evm_address, new Date().getTime().toString());
      setMessage(resp);
      const invoice = JSON.parse(resp).payment_request;
      const signer = await provider.getSigner();
      const signature = await signer.signMessage(petitionToSolve.current.proofTxId);
      if (typeof window.webln !== 'undefined') {
        await window.webln.enable();
        setMessage(`Pay invoice ${invoice}`);
        const result = await window.webln.sendPayment(invoice);
        setMessage("Invoice paid, wait for service send evm transaction ...");
        const resp = await main.solvePetitionEVM2LN(
          invoice,
          petitionToSolve.current.proofTxId,
          petitionToSolve.current.proofTxId,
          signature,
          coinbase.toLowerCase(),
          new Date().getTime().toString()
        );
        setMessage(resp);
        setTimeout(() => {
          fetchPetitions();
        }, 1000);
      } else {
        setMessage(`Pay invoice: ${invoice} and go step2: checkInvoice with payment hash: ${r_hashUrl}`)
      };
    } catch (err) {
      setMessage(err.message);
      setTimeout(() => {
        setMessage();
      }, 2000)
    }
  };

  const solveEVM2LNPetition = async () => {
    setMessage("Sign");
    const signer = await provider.getSigner();
    const signature = await signer.signMessage(petitionToSolve.current.proofTxId);
    setMessage("Checking parameters and processing evm payment ...");
    const resp = await main.solvePetitionEVM2LN(
      petitionToSolve.current.invoiceId,
      petitionToSolve.current.proofTxId,
      petitionToSolve.current.proofTxId,
      signature,
      coinbase.toLowerCase(),
      new Date().getTime().toString()
    );
    setMessage(resp);
    setTimeout(() => {
      fetchPetitions();
    }, 1000);
  }

  const checkInvoice = async () => {
    setProcessing(true);
    try {
      setMessage("Processing evm transaction ...");
      const wbtcAddressWanted = chains.filter(item => item.chainId === Number(JSON.parse(chain).chainId))[0].wbtcAddress;
      const resp = await main.petitionLN2EVM(
        {
          proofTxId: "0",
          invoiceId: "null",
          petitionPaidInvoice: petitionPaidInvoice,
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
      setMessage(resp);
      setTimeout(() => {
        fetchPetitions();
      }, 1000);
    } catch (err) {
      setMessage(`${err.message}`)
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

  useEffect(() => {
    if (Number(netId) === 31) {
      setExplorerBaseUrl("https://explorer.testnet.rsk.co/tx/");
    } else {
      setExplorerBaseUrl("https://sepolia.etherscan.io/tx/");
    }
  }, [netId]);

  useEffect(() => {
    if (currentPetitionToSolve) {
      petitionToSolve.current = currentPetitionToSolve;
    }
  }, [currentPetitionToSolve]);

  return (
    <div className="w-full p-4">
      <h1 className="text-2xl font-bold text-center mb-6">PetitionsLN</h1>

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
          <CreatePetitionLN
            canisterAddr={canisterAddr}
            chain={chain}
            chains={chains}
            setChain={setChain}
            setEvmAddr={setEvmAddr}
            setAmount={setAmount}
            sendToken={sendToken}
            netId={netId}
            evm_address={evm_address}
            amount={amount}
            coinbase={coinbase}
            processing={processing}
            loadWeb3Modal={loadWeb3Modal}
            sendPetitionTxHash={sendPetitionTxHash}
            ln={ln}
            setLN={setLN}
            evm_txHash={evm_txHash}
            setEvmTxHash={setEvmTxHash}
            getInvoice={getInvoice}
            r_hash={r_hash}
            checkInvoice={checkInvoice}
          /> :
          <SolvePetitionsLN
            petitions={petitions}
            petitionToSolve={petitionToSolve}
            solveEVM2LNPetition={solveEVM2LNPetition}
            setCurrentPetitionToSolve={setCurrentPetitionToSolve}
            currentPetitionToSolve={currentPetitionToSolve}
            evm_txHash={evm_txHash}
            netId={netId}
            sendToken={sendToken}
            solve={solve}
            processing={processing}
            setAmount={setAmount}
            payPetitionInvoice={payPetitionInvoice}
          />
      }

      {message && (
        <div className="p-3 rounded mt-3 break-all bg-blue-100 text-blue-700">
          {message}
        </div>
      )}
    </div>
  );
};

export default PetitionsLN;