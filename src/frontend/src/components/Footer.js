import React from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faExternalLink } from '@fortawesome/free-solid-svg-icons';

const Footer = () => {
  return (
    <footer className="bg-gray-800 text-white py-4">
      <div className="container mx-auto flex justify-center items-center">
        <a
          href="https://github.com/Bitcoin-AI/icp-canister-bridge"
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center space-x-2 text-white hover:text-gray-300"
        >
          <FontAwesomeIcon icon={faExternalLink} />
          <span>GitHub</span>
        </a>
      </div>
    </footer>
  );
};

export default Footer;