import React, {useContext} from 'react';

import { decode } from 'light-bolt11-decoder';
import { AppContext } from '../../AppContext';

const SolvePetitionsLN = ({
    sendToken,
    petitions,
    payPetitionInvoice,
    petitionToSolve,
    currentPetitionToSolve,
    solveEVM2LNPetition,
    setCurrentPetitionToSolve,
    solve
}) => {


  const { 
    processing,
    evm_txHash,
    setEvmTxHash,
  } = useContext(AppContext);

  return (
    <div className="mb-6">
    <div className="mb-4">
      <h2>Petitions</h2>
      {
        petitions.map(item => {
          if (item.sendingChain !== "0" && item.wantedChain !== "0") return;
          return (
            <div key={item.proofTxId !== "0" ? item.proofTxId : item.petitionPaidInvoice} className="mb-4">
              <p>From: {item.sendingChain !== "0" ? item.sendingChain : "Bitcoin Lightning Network"}</p>
              <p>To: {item.wantedChain !== "0" ? item.wantedChain : "Bitcoin Lightning Network"}</p>
              {
                item.proofTxId === "0" ?
                  item.sendingChain !== "0" ?
                    (
                      item.sendingChain === "0x1f" ?
                        <p>Amount: {(Number(item.transaction.value) / 10 ** 10)?.toString()} satoshis of rbtc</p> :
                        <p>Amount: {(Number(`0x${item.transaction.data.slice(74).replace(/^0+/, '')}`) / 10 ** 10).toString()} satoshis of wbtc</p>
                    ) :
                    item.petitionPaidInvoice?.indexOf("lntb") !== -1 &&
                    <>
                      <p style={{ overflowX: 'auto' }}>{item.petitionPaidInvoice}</p>
                      <p>Amount: {(Number(item.decodedPetitionPaidInvoice.sections[2].value) / 1000).toString()} satoshis</p>
                    </> :
                    <>
                      <p style={{ overflowX: 'auto' }}>{item.invoiceId}</p>
                      <p>Amount: {(Number(decode(item.invoiceId).sections[2].value) / 1000).toString()} satoshis</p>
                    </>
              }
              <p>Reward: {item.reward}</p>
              {
                currentPetitionToSolve &&
                (
                  JSON.stringify(currentPetitionToSolve) === JSON.stringify(item) &&
                  <p><b>Petition Selected</b></p>
                )
              }
              <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={async () => {
                petitionToSolve.current = item;
                setCurrentPetitionToSolve(item);
                if (item.invoiceId.indexOf("lntb") !== -1) {
                  const amt = (Number(decode(item.invoiceId).sections[2].value) / 1000).toString();
                  payPetitionInvoice(amt);
                } else {
                  sendToken();
                };
                return;
              }}>Initiate petition solving</button>
              {
                !currentPetitionToSolve &&
                <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={async () => {
                  setCurrentPetitionToSolve(item);
                }}>Select Petition</button>
              }
            </div>
          );
        })
      }
    </div>
    {
      petitionToSolve.current &&
      (
        petitionToSolve.current?.petitionPaidInvoice !== "0" ?
          <>
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
            {
              !processing ?
                <button className="w-full p-2 mt-2 bg-blue-500 text-white rounded" onClick={solveEVM2LNPetition}>Get Payment</button> :
                <button className="w-full p-2 mt-2 bg-gray-400 text-white rounded" onClick={solveEVM2LNPetition} disabled>Wait current process</button>
            }
          </>
      )
    }
  </div>
  );
};

export default SolvePetitionsLN;