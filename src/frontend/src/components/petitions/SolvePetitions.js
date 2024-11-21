
import React, {useContext} from 'react';

import { AppContext } from '../../AppContext';

const SolvePetitions = ({
    sendToken,
    petitions,
    petitionToSolve,
    solve
}) => {
  const { netId } = useContext(AppContext);
  
  return (
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
  );
};

export default SolvePetitions;