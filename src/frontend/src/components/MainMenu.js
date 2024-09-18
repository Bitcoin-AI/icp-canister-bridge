import React, { useEffect, useState } from "react";
import { useLocation, Link } from 'react-router-dom';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faBolt,faLightbulb, faExchangeAlt, faPaperPlane, faBullhorn } from '@fortawesome/free-solid-svg-icons';

const MainMenu = () => {
  const location = useLocation();
  const [activeTab, setActiveTab] = useState('/');

  useEffect(() => {
    setActiveTab(location.pathname);
  }, [location.pathname]);

  const handleChange = (newValue) => {
    setActiveTab(newValue);
  };

  const tabs = [
    {
      label: 'EVM to Lightning',
      icon: <FontAwesomeIcon icon={faBolt} />,
      path: '/',
    },
    {
      label: 'Lightning to EVM',
      icon: <FontAwesomeIcon icon={faLightbulb} />,
      path: '/lightningToEvm',
    },
    {
      label: 'EVM to EVM',
      icon: <FontAwesomeIcon icon={faExchangeAlt} />,
      path: '/evmToEvm',
    },
    {
      label: 'Petitions EVM to EVM',
      icon: <FontAwesomeIcon icon={faPaperPlane} />,
      path: '/petitionsEvm',
    },
    {
      label: 'Petitions LN and EVM',
      icon: <FontAwesomeIcon icon={faBullhorn} />,
      path: '/petitionsLN',
    },
  ];

  return (
    <div className="w-full bg-gray-100 flex justify-center items-center">
      <div className="flex overflow-x-auto space-x-4 p-4">
        {tabs.map((tab, index) => (
          <Link
            key={index}
            to={tab.path}
            className={`flex items-center px-4 py-2 rounded-lg ${
              activeTab === tab.path ? 'bg-blue-500 text-white' : 'text-gray-700 hover:bg-gray-200'
            }`}
            onClick={() => handleChange(tab.path)}
          >
            {/* {tab.icon} */}
            {tab.icon} <span className="ml-2">{tab.label}</span>
          </Link>
        ))}
      </div>
    </div>
  );
};

export default MainMenu;