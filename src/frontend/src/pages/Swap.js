import React, { useContext, useState, useEffect } from "react";
import { Link } from 'react-router-dom';
import { ethers } from "ethers";


import { AppContext } from '../AppContext';

import { Button } from "../components/ui/Button";
import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
} from "../components/ui/Card";

import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "../components/ui/Select"
  
import { Input } from "../components/ui/Input"

const Swap = () => {



  const { 
    chains,
    fetchBalance,
    fetchLNBalance,
    coinbase,
    canisterAddr
  } = useContext(AppContext);

  const [originChain, setOriginChain] = useState();
  const [originUserBalance, setOriginUserBalance] = useState();
  const [destinationChain, setDestinationChain] = useState();
  const [canisterBalance,setCanisterBalance] = useState();

  const [amount, setAmount] = useState();

  useEffect(() => {
    if(coinbase && originChain){
      const netId = JSON.parse(originChain).chainId;
      const rpc = JSON.parse(originChain).rpc;
      const chainProvider = new ethers.JsonRpcProvider(rpc);
      fetchBalance(coinbase,chainProvider,netId).then(balance => {
        setOriginUserBalance(balance);
      })
    }
  },[originChain,coinbase]);

  useEffect(() => {
    if(canisterAddr && destinationChain){
      const netId = JSON.parse(destinationChain).chainId;
      const rpc = JSON.parse(destinationChain).rpc;
      const chainProvider = new ethers.JsonRpcProvider(rpc);
      if(chainProvider && rpc && netId){
        fetchBalance(`0x${canisterAddr}`,chainProvider,netId).then(balance => {
            setCanisterBalance((Number(balance)/10**10).toString());
          });
      } else {
        fetchLNBalance().then(response => {
            setCanisterBalance(response.data.balance)
        });
      }


    }
  },[canisterAddr,destinationChain]);

  return (
    <div className="flex items-center justify-center">
      <div className="container mx-auto p-4">

        <h1 className="text-2xl font-bold text-center mb-6">Swap</h1>

        {/* Step 1 */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <Card>
                <CardHeader>
                    <CardTitle>Origin Chain</CardTitle>
                    <CardDescription>{originChain?.name}</CardDescription>
                </CardHeader>
                <CardContent>
                <Select onValueChange={(value) => setOriginChain(value)}>
                    <SelectTrigger className="w-full">
                        <SelectValue placeholder="Origin Chain" />
                    </SelectTrigger>
                    <SelectContent>
                    {
                        chains.map(item => (
                        <SelectItem key={item.chainId} value={JSON.stringify(
                            {
                            rpc: item.rpc.filter(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}"))[0],
                            chainId: item.chainId,
                            name: item.name
                            }
                        )}>{item.name}</SelectItem>
                        ))
                    }
                    <SelectItem key={"lightning"} value={JSON.stringify(
                        {
                            rpc: null,
                            chainId: null,
                            name: "Lightning"
                        }
                    )}>{`Lightning`}</SelectItem>
                    </SelectContent>
                </Select>
                </CardContent>
            </Card>
            <Card>
                <CardHeader>
                    <CardTitle>Destination Chain</CardTitle>
                    <CardDescription></CardDescription>
                </CardHeader>
                <CardContent>
                <Select className="w-full" onValueChange={(value) => setDestinationChain(value)}>
                    <SelectTrigger>
                        <SelectValue placeholder="Destination Chain" />
                    </SelectTrigger>
                    <SelectContent>
                    {
                        chains.map(item => (
                        <SelectItem key={item.chainId} value={JSON.stringify(
                            {
                            rpc: item.rpc.filter(rpcUrl => !rpcUrl.includes("${INFURA_API_KEY}"))[0],
                            chainId: item.chainId,
                            name: item.name
                            }
                        )}>{item.name}</SelectItem>
                        ))
                    }
                    <SelectItem key={"lightning"} value={JSON.stringify(
                        {
                            rpc: null,
                            chainId: null,
                            name: "Lightning"
                        }
                    )}>{`Lightning`}</SelectItem>
                    </SelectContent>
                </Select>
                </CardContent>
            </Card>
        </div>
        <Card>
            <CardHeader>
                <CardTitle>Amount</CardTitle>
                <CardDescription>Amount in satoshis</CardDescription>
            </CardHeader>
            <CardContent>
            <Input
                value={amount}
                onChange={(ev) => setAmount(ev.target.value)}
                placeholder="Satoshis"
            />
            </CardContent>
            <CardFooter>
                <div className="w-full">
                {
                originChain &&
                <p className="text-sm text-gray-600">
                    Bridging from <strong>{JSON.parse(originChain).name}</strong> (Chain ID: {JSON.parse(originChain).chainId})
                </p>
                }
                {
                destinationChain &&
                <p className="text-sm text-gray-600">
                    Bridging to <strong>{JSON.parse(destinationChain).name}</strong> (Chain ID: {JSON.parse(destinationChain).chainId})
                </p>
                }
                {
                amount &&
                <p className="text-sm text-gray-600">
                    Amount: {amount} satoshis
                </p>
                }
                {
                canisterBalance && 
                <p className="text-sm text-gray-600" >
                   <strong>Total Liquidity on Destination ({JSON.parse(destinationChain).name}) : {canisterBalance.toString()} satoshis</strong>
                </p>
                } 
                {
                    amount > 0 && destinationChain && originChain && originUserBalance && canisterBalance &&
                    (
                        <>
                        {
                            (amount > Number(originUserBalance) || amount > Number(canisterBalance)) ?
                            <div>
                                <Button variant="destructive" size="lg">Invalid Amount</Button>
                            </div> :
                            <>
                            {
                            JSON.parse(destinationChain).name === "Lightning" &&
                            <Link to={`/swap/evmToLightning?amount=${amount}&destinationChain=${destinationChain}&originChain=${originChain}`}>
                                <Button variant="info" size="lg">Perform EVM to Lightning swap</Button>
                            </Link>
                            }
                            {
                            JSON.parse(originChain).name === "Lightning" && JSON.parse(destinationChain).name !== "Lightning" &&
                            <Link to={`/swap/lightningToEvm?amount=${amount}&destinationChain=${destinationChain}&originChain=${originChain}`}>
                                <Button variant="info" size="lg">Perform Lightning to EVM swap</Button>
                            </Link>
                            }
                            {
                            JSON.parse(originChain).name !== "Lightning" && JSON.parse(destinationChain).name !== "Lightning" &&
                            <Link to={`/swap/evmToEvm?amount=${amount}&destinationChain=${destinationChain}&originChain=${originChain}`}>
                                <Button variant="info" size="lg">Perform EVM to EVM swap</Button>
                            </Link>
                            }
                            </>
                        }

                        </>

                    )
                }
                </div>
            </CardFooter>
        </Card>
      </div>
    </div>
  );
};

export default Swap;