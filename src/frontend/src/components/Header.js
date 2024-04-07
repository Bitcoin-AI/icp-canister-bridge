import React from "react";
import styles from '../RSKLightningBridge.module.css';  // Import the CSS module



const Header = ({
    nodeInfo,
    netId,
    coinbase,
    fetchNodeInfo,
    rskBalance
}) => {

  return (
    <>
      <div className={styles.header}>
        <p>Welcome to EVM Lightning Bridge!</p>
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
          <p>EVM chainId: {netId.toString()}</p>
          <p>EVM sats balance: {Math.round(rskBalance/10**10)} satoshis of {netId === 31 ? "rbtc" : "wbtc"}</p>
        </div>
      }
    </>
  );

};

export default Header;