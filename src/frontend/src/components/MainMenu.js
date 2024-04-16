import React,{useEffect,useState} from "react";
import { useLocation,Link } from 'react-router-dom';

import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faBolt,faLightbulb, faExchangeAlt, faPaperPlane, faBullhorn } from '@fortawesome/free-solid-svg-icons';
import styles from '../RSKLightningBridge.module.css';  // Import the CSS module



const MainMenu = () => {
  let location = useLocation();
  const [activeTab,setActiveTab] = useState('rskToLight');
  useEffect(() => {
    if(location.pathname === "/"){
      setActiveTab("rskToLight");
    }
    if(location.pathname === "/lightningToEvm"){
      setActiveTab("lightToRSK");
    }
    if(location.pathname === "/evmToEvm"){
      setActiveTab("evmToEvm");
    }
    if(location.pathname === "/petitionsEvm"){
      setActiveTab("petitions");
    }
    if(location.pathname === "/petitionsLN"){
      setActiveTab("petitionsLN");
    }
  },[location.pathname]);
  return (
    <div className={styles.tabs}>
      <Link to='/'>
        <button
          className={activeTab === 'rskToLight' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('rskToLight');
          }}
        >
          <FontAwesomeIcon icon={faBolt} /> EVM to Lightning
        </button>
      </Link>
      <Link to='/lightningToEvm'>
        <button
          className={activeTab === 'lightToRSK' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('lightToRSK');
          }}
        >
          <FontAwesomeIcon icon={faExchangeAlt} /> Lightning to EVM
        </button>
      </Link>
      <Link to="/evmToEvm">
        <button
          className={activeTab === 'evmToEvm' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('evmToEvm');
          }}
        >
          <FontAwesomeIcon icon={faExchangeAlt} /> EVM to EVM
        </button>
      </Link>
      <Link to='/petitionsEvm'>
        <button
          className={activeTab === 'petitions' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('petitions');
          }}
        >
          <FontAwesomeIcon icon={faPaperPlane} /> Petitions EVM to EVM
        </button>
      </Link>
      <Link to="/petitionsLN">
        <button
          className={activeTab === 'petitionsLN' ? styles.activeTab : ''}
          onClick={() => {
            setActiveTab('petitionsLN');
          }}
        >
          <FontAwesomeIcon icon={faBullhorn} /> Petitions between LN and EVM
        </button>
      </Link>
    </div>
  );

};

export default MainMenu;