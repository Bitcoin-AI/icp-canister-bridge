import React, { useContext } from "react";
import { Link } from 'react-router-dom';
import { AvatarIcon } from "@radix-ui/react-icons";

import { AppContext } from '../AppContext';

import MainMenu from "./MainMenu";

import {
  Avatar,
  AvatarFallback,
  AvatarImage,
} from "./ui/Avatar";

const Header = () => {

  const {
    coinbase,
  } = useContext(AppContext);

  return (
    <header className="bg-gray-800 text-white shadow">
      <div className="container mx-auto px-4 py-2 flex justify-between items-center">
        <h1 className="text-lg font-semibold">Senfina</h1>
        <MainMenu />
        <Link to="/info" className="flex items-center justify-center h-12 w-12">
          <AvatarIcon className="h-8 w-8" /> {/* Increased from h-6 w-6 to h-8 w-8 */}
          {coinbase && (
          <div className="h-6 w-4" title="Connected Wallet">
            <button className="text-white hover:underline">
              {`${coinbase.substring(0, 6)}...${coinbase.substring(coinbase.length - 4)}`}
            </button>
          </div>
        )}
        </Link>

      </div>
    </header>
  );
};

export default Header;