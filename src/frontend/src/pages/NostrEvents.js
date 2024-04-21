import React,{useRef} from "react";
import useNostr from "../hooks/useNostr";



import styles from '../RSKLightningBridge.module.css';  // Import the CSS module
const NostrEvents = () => {

  const {
    events,
    npub
  } = useNostr();
  
  return(
    <div>
      {/* Content for nostr messages */}
      <h3>Invoices paid by service</h3>
      <p><a href={`https://iris.to/${npub}`} target="_blank">See at iris.to</a></p>
      {
        events.map(e => {

          return (
            <div key={e.id} className={styles.step} style={{ overflowX: "auto" }}>
              <div>{new Date(e.created_at * 1000).toString()}</div>
              <div>{e.content}</div>
            </div>
          )
        })
      }
    </div>
  );
};
export default NostrEvents;