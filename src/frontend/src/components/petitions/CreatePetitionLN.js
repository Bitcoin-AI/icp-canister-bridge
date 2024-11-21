import React, {useContext} from 'react';

import { AppContext } from '../../AppContext';

const CreatePetitionLN = ({
    chain,
    setChain,
    setAmount,
    sendToken,
    amount,
    setLN,
    ln,
    sendPetitionTxHash,
    solve,
    petitionPaidInvoice,
    getInvoice,
    r_hash,
    checkInvoice
  }) => {

  const { 
    coinbase,
    netId,
    canisterAddr,
    loadWeb3Modal,
    chains,
    processing,
    evm_txHash,
    setEvmTxHash,
    evm_address,
    setEvmAddr,
  } = useContext(AppContext);
  
  return (
    <div className="mb-6">
        <div className="mb-4">
        <select
            className="w-full p-2 border border-gray-300 rounded mb-4"
            onChange={(ev) => { setLN(!ln) }}
            defaultValue={false}
        >
            <option value={false}>EVM to Lightning</option>
            <option value={true}>Lightning to EVM</option>
        </select>
        </div>
        {
        !ln ?
            <>
            <div className="mb-4">
                <p>Send token to 0x{canisterAddr}</p>
                <p>Sending from chainId {netId?.toString()}</p>
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
            </> :
            <>
            <div className="mb-4">
                <p>Step 1: Request an invoice to swap to EVM compatible chain</p>
                <label className="block mb-2">Amount (satoshi)</label>
                <input
                className="w-full p-2 border border-gray-300 rounded mb-4"
                value={amount}
                onChange={(ev) => setAmount(ev.target.value)}
                placeholder="Enter amount"
                />
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
                    <option value={JSON.stringify(
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
                <p className="text-sm text-gray-600">
                    Bridging to <strong>{JSON.parse(chain).name}</strong> (Chain ID: {JSON.parse(chain).chainId})
                </p>
                }
                {
                !processing ?
                    <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={getInvoice}>Get Invoice!</button> :
                    <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" onClick={getInvoice} disabled>Wait current process</button>
                }
                <p>Step 2 {typeof (window.webln) !== 'undefined' && '(Optional)'}: Input r_hash from the invoice generated by the service after you pay it</p>
                <input
                className="w-full p-2 border border-gray-300 rounded mb-4"
                value={r_hash}
                onChange={(ev) => setPaymentHash(ev.target.value)}
                placeholder="Enter r_hash"
                />
                {
                !processing ?
                    <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={checkInvoice}>Check Invoice!</button> :
                    <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" onClick={checkInvoice} disabled>Wait current process</button>
                }
                {
                petitionPaidInvoice &&
                <>
                    <p>Invoice to be paid:</p>
                    <p style={{ overflowX: "auto" }}>{petitionPaidInvoice}</p>
                </>
                }
            </div>
            </>
        }
    </div>
  );
};

export default CreatePetitionLN;