import React from "react";

const Info = ({
  nodeInfo,
  netId,
  coinbase,
  fetchNodeInfo,
  rskBalance
}) => {
  return (
    <>
      {/* Main Content */}
      <main className="flex-grow flex flex-col container mx-auto px-4 mt-8">
        <div className="bg-white shadow-lg p-6 rounded-lg">
          {/* Node Info Section */}
          {typeof window.webln !== 'undefined' && (
            <div className="mt-8">
              <h3 className="text-xl font-bold mb-4">Lightning Node Information</h3>
              <button
                className="bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600"
                onClick={fetchNodeInfo}
              >
                Fetch Node Info
              </button>
              {nodeInfo && (
                <div className="bg-gray-100 p-4 rounded-lg shadow-md mt-4">
                  <div className="flex items-center">
                    <div className="w-12 h-12 rounded-full bg-gray-300 flex items-center justify-center mr-4">
                      <span className="text-xl font-bold">{nodeInfo.node.alias.charAt(0)}</span>
                    </div>
                    <div>
                      <h4 className="text-lg font-semibold">{nodeInfo.node.alias}</h4>
                      <p className="text-sm break-all">Pubkey: {nodeInfo.node.pubkey}</p>
                      <p className="text-sm">Balance: {nodeInfo.balance} sats</p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* EVM Info Section */}
          {coinbase && (
            <div className="mt-8">
              <h3 className="text-xl font-bold mb-4">EVM Connection</h3>
              <div className="bg-gray-100 p-4 rounded-lg shadow-md mt-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <p className="text-base"><strong>Address:</strong><br />{coinbase}</p>
                  </div>
                  <div>
                    <p className="text-base"><strong>Chain ID:</strong> {netId.toString()}</p>
                  </div>
                  <div className="sm:col-span-2">
                    <p className="text-base"><strong>Balance:</strong> {Math.round(rskBalance / 10 ** 10)} satoshis of {netId === 31 ? "RBTC" : "WBTC"}</p>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>
    </>
  );
};

export default Info;