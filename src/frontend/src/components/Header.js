import React from "react";
import '../input.css'; // Import the Tailwind CSS file

const Header = ({
  nodeInfo,
  netId,
  coinbase,
  fetchNodeInfo,
  rskBalance
}) => {
  return (
    <>
      {/* AppBar Header */}
      <header className="bg-gray-800 text-white shadow">
        <div className="container mx-auto px-4 py-2 flex justify-between items-center">
          <h1 className="text-lg font-semibold">EVM Lightning Bridge</h1>
          {coinbase && (
            <div className="relative" title="Connected Wallet">
              <button className="text-white hover:underline">
                {`${coinbase.substring(0, 6)}...${coinbase.substring(coinbase.length - 4)}`}
              </button>
            </div>
          )}
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 mt-8">
        <div className="bg-white shadow-lg p-6 rounded-lg">
          <h2 className="text-2xl font-bold mb-4">Welcome to EVM Lightning Bridge!</h2>
          <p className="mb-4">Follow the steps below to bridge your assets.</p>

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

export default Header;