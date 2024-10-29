import React, { useEffect, useState } from "react";
import { useLocation, Link } from 'react-router-dom';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faBolt,faLightbulb, faExchangeAlt, faPaperPlane, faBullhorn,faHome,faInfo } from '@fortawesome/free-solid-svg-icons';

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
      label: 'Home',
      icon: <FontAwesomeIcon icon={faHome} />,
      path: '/',
    },
    {
      label: 'Swap',
      icon: <FontAwesomeIcon icon={faExchangeAlt} />,
      path: '/swap',
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
    <div className="w-full flex justify-center items-center">
      <div className="flex overflow-x-auto space-x-4 p-4">
        {tabs.map((tab, index) => (
          <Link
            key={index}
            to={tab.path}
            className={`flex items-center px-4 py-2 rounded-lg ${
              activeTab === tab.path ? 'bg-blue-500 text-gray-100' : 'text-white hover:bg-gray-200'
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