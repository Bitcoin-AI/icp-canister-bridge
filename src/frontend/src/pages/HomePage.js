import React from 'react';

const HomePage = () => {
  return (
    <div className="flex-grow bg-gray-100 flex flex-col items-center justify-center">
      <h4 className="text-2xl font-bold text-center mb-6">Senfina</h4>
      <div className="w-full max-w-4xl mt-8">
        <h2 className="text-2xl font-bold mb-4">Welcome to Senfina</h2>
        <p className="text-gray-700 mb-6">
          Learn how to use our app to bridge assets between EVM and Lightning Network.
        </p>
        <div className="space-y-6">
          <div>
            <h3 className="text-lg font-semibold mb-2">Step 1: Connect Your Wallet</h3>
            <p className="text-gray-700">
              To get started, click the "Connect Wallet" button at the top right corner of the page. This will allow you to interact with the app using your Ethereum wallet.
            </p>
          </div>
          <div>
            <h3 className="text-lg font-semibold mb-2">Step 2: Select Your Bridge</h3>
            <p className="text-gray-700">
              Once your wallet is connected, you can select the bridge you want to use. We offer bridges for EVM to Lightning, Lightning to EVM, and EVM to EVM.
            </p>
          </div>
          <div>
            <h3 className="text-lg font-semibold mb-2">Step 3: Initiate the Transfer</h3>
            <p className="text-gray-700">
              After selecting the bridge, follow the on-screen instructions to initiate the transfer. You will need to approve the transaction in your wallet.
            </p>
          </div>
          <div>
            <h3 className="text-lg font-semibold mb-2">Step 4: Monitor Your Transfer</h3>
            <p className="text-gray-700">
              You can monitor the status of your transfer in the "Petitions" section. Once the transfer is complete, you will see the updated balance in your wallet.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default HomePage;