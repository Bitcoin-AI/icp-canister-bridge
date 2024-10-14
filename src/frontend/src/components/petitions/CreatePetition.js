
import React from 'react';

const CreatePetition = ({
    chain,
    chains,
    setChain,
    setEvmAddr,
    setAmount,
    sendToken,
    netId,
    evm_address,
    canisterAddr,
    amount,
    coinbase,
    processing,
    loadWeb3Modal
}) => {
  return (
    <div className="w-full">
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
    </div> 
  );
};

export default CreatePetition;