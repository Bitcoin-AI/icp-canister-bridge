import React from 'react';
import { render } from "react-dom";
import { HashRouter as Router } from 'react-router-dom';
import { AppProvider } from './AppContext';
import App from './App';
import './input.css';

render(
  <React.StrictMode>
    <AppProvider>
      <Router>
        <App />
      </Router>
    </AppProvider>
  </React.StrictMode>,
  document.getElementById("app")
);
