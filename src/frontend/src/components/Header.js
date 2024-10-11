import React from "react";

import MainMenu from "./MainMenu";

const Header = ({
  coinbase,
}) => {
  return (
    <header className="bg-gray-800 text-white shadow">
    <div className="container mx-auto px-4 py-2 flex justify-between items-center">
      <h1 className="text-lg font-semibold">Senfina</h1>
      <MainMenu />
      {coinbase && (
        <div className="relative" title="Connected Wallet">
          <button className="text-white hover:underline">
            {`${coinbase.substring(0, 6)}...${coinbase.substring(coinbase.length - 4)}`}
          </button>
        </div>
      )}
    </div>
  </header>
  );
};

export default Header;