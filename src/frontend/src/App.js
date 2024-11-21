import React, { useContext } from "react";
import { Route, Routes,Navigate } from 'react-router-dom';


import Header from "./components/Header";
import Info from "./components/Info";
import Footer from "./components/Footer";

import HomePage from "./pages/HomePage";
import Swap from "./pages/Swap";

import EvmToLightning from "./pages/EvmToLightning";
import EvmToEvm from "./pages/EvmToEvm";
import LightningToEvm from "./pages/LightningToEvm";
import Petitions from "./pages/Petitions";
import PetitionsLN from "./pages/PetitionsLN";
import { AppContext } from './AppContext';


const App = () => {

  // State hooks
  const { canisterAddr } = useContext(AppContext); 

  return (
    <div className="flex flex-col min-h-screen bg-gray-100">
      <Header />
      {
        canisterAddr ?
        <div className="flex-grow self-center w-6/12		">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/info" element={<Info/>}  />
          <Route path="/swap" element={<Swap/>} />
          <Route path="/swap/evmToLightning" element={<EvmToLightning/>} />
          <Route path="/swap/lightningToEvm" element={<LightningToEvm/>} />
          <Route path="/swap/evmToEvm" element={<EvmToEvm/>} />
          <Route path="/petitionsEvm" element={<Petitions />} />
          <Route path="/petitionsLN" element={<PetitionsLN />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </div> :
      <p className="flex-grow" >Loading Canister ...</p>
      }

      <Footer />
    </div>
  );

};

export default App;