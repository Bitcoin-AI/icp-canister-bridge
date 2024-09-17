import React, { useEffect, useState } from "react";
import { useLocation, Link } from 'react-router-dom';
import { Tabs, Tab, Box, Typography } from '@mui/material';
//import { Bolt, SwapHoriz, Send, Campaign } from '@mui/icons-material';

const MainMenu = () => {
  const location = useLocation();
  const [activeTab, setActiveTab] = useState('/');

  useEffect(() => {
    setActiveTab(location.pathname);
  }, [location.pathname]);

  const handleChange = (event, newValue) => {
    setActiveTab(newValue);
  };

  const tabs = [
    {
      label: 'EVM to Lightning',
      //icon: <Bolt />,
      path: '/',
    },
    {
      label: 'Lightning to EVM',
      //icon: <SwapHoriz />,
      path: '/lightningToEvm',
    },
    {
      label: 'EVM to EVM',
      //icon: <SwapHoriz />,
      path: '/evmToEvm',
    },
    {
      label: 'Petitions EVM to EVM',
      //icon: <Send />,
      path: '/petitionsEvm',
    },
    {
      label: 'Petitions LN and EVM',
      //icon: <Campaign />,
      path: '/petitionsLN',
    },
  ];

  return (
    <Box sx={{ width: '100%', bgcolor: 'background.paper' }}>
      <Tabs
        value={activeTab}
        onChange={handleChange}
        variant="scrollable"
        scrollButtons
        allowScrollButtonsMobile
        indicatorColor="primary"
        textColor="primary"
        centered
      >
        {tabs.map((tab, index) => (
          <Tab
            key={index}
            label={
              <Box sx={{ display: 'flex', alignItems: 'center' }}>
                {tab.icon}
                <Typography sx={{ marginLeft: 1 }}>{tab.label}</Typography>
              </Box>
            }
            value={tab.path}
            component={Link}
            to={tab.path}
          />
        ))}
      </Tabs>
    </Box>
  );
};

export default MainMenu;