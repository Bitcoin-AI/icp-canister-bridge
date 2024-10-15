import React, { useContext,useEffect, useState } from "react";
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faChevronUp,faChevronDown ,faCopy} from '@fortawesome/free-solid-svg-icons';
import { AppContext } from '../AppContext';

const TransactionsList = ({
    name
}) => {

  const { netId,setEvmTxHash } = useContext(AppContext);

  const [previousSwaps,setPreviousSwaps] = useState([]);
  const [successSwaps,setSuccessSwaps] = useState([]);
  const [pendingSwaps,setPendingSwaps] = useState([]);
  const [isOpen, setIsOpen] = useState(false);

  useEffect(() => {
    const storagePreviousSwaps = localStorage.getItem(`${name}_previousSwaps`);
    console.log(storagePreviousSwaps)
    console.log(Number(netId))
    setPreviousSwaps(storagePreviousSwaps ? JSON.parse(storagePreviousSwaps) : []);
  },[localStorage.getItem(`${name}_previousSwaps`)]);
  useEffect(() => {
    const storageSuccessFullSwaps = localStorage.getItem(`${name}_successSwaps`);
    setSuccessSwaps(storageSuccessFullSwaps ? JSON.parse(storageSuccessFullSwaps) : []);
  },[localStorage.getItem(`${name}_successSwaps`)]);
  useEffect(() => {
    if(previousSwaps?.length > 0 && successSwaps?.length > 0){
      const result = previousSwaps.reduce((acc, item) => {
        if (!successSwaps.includes(item)) {
          acc.push(item);
        }
        return acc;
      }, []);
      console.log(result);
      setPendingSwaps(result);
    }
  },[previousSwaps,successSwaps]);



  return (
    <div className="w-full justify-center items-center">

      <button
        onClick={() => setIsOpen(!isOpen)}
        className="bg-blue-500 text-white px-4 py-2 rounded shadow-md hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50"
      >
        {isOpen ? <FontAwesomeIcon icon={faChevronDown} />  : <FontAwesomeIcon icon={faChevronUp} />}
         Transactions Sent
      </button>
      <div
        className={`mt-4 p-4 transition-all duration-300 ease-in-out ${
          isOpen ? 'max-h-96' : 'max-h-0 overflow-hidden'
        }`}
      >
      <div className="space-x-4 w-full">
            <ul className="space-y-4">
            {
                previousSwaps?.map(item => {
                    const swap = JSON.parse(item);
                    if(Number(swap.netId) === Number(netId)){
                        return(
                            <li key={swap.txHash} className="bg-gray-100 p-4 rounded shadow-md">
                            <FontAwesomeIcon icon={faCopy} onClick={() =>{
                                setEvmTxHash(swap.txHash)
                            }}/> {swap.txHash}
                            </li>
                        )
                    }
                })
            }
        </ul> 
      </div>
      </div>

    </div>
  );
};

export default TransactionsList;