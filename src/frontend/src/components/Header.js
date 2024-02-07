import React from "react";
import styles from '../RSKLightningBridge.module.css';  // Import the CSS module



const Header = ({
    nodeInfo,
    coinbase,
    fetchNodeInfo,
    rskBalance
}) => {

  return (
    <>
      <div className={styles.header}>
        <p>Welcome to RSK Lightning Bridge!</p>
        <p>Follow the steps below to bridge your assets.</p>
      </div>
      {
        typeof(window.webln) !== 'undefined' &&

          <div className={styles.balance}>
            <button className={styles.button} onClick={fetchNodeInfo}>Fetch Node Info</button>
            {
              nodeInfo &&
              <>
              <p>Alias {nodeInfo.node.alias}</p>
              <p>Pubkey {nodeInfo.node.pubkey}</p>
              <p>Balance: {nodeInfo.balance} sats</p>
              </>
            }
          </div>
      }
      {
        coinbase &&
        <div className={styles.balance}>
          <p>EVM connected as {coinbase}</p>
          <p>Your RSK Balance: {rskBalance/10**10} satoshis of rbtc</p>
        </div>
      }
    </>
  );

};

export default Header;