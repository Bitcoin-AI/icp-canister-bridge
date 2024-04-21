import {  useEffect,useState,useRef } from "react";
import {
  SimplePool,
  nip19,
} from 'nostr-tools';



function useNostr(){

  const pk = "c6d88b290e99b4f3442f034558356987990d415a0641b4faa7f39aa12dd9aa94";
  const npub = nip19.npubEncode(pk)

  const relays = [
    'wss://relay.damus.io',
    'wss://eden.nostr.land',
    'wss://nostr-pub.wellorder.net',
    'wss://nostr.fmt.wiz.biz',
    'wss://relay.snort.social',
    'wss://nostr-01.bolt.observer',
    'wss://offchain.pub'
  ];
  const eventsRef = useRef(new Array());
  const [events,setEvents] = useState([]);
  const pool = new SimplePool()

  useEffect(() => {

    const sub = pool.sub(
      relays,
      [
        {
          kinds: [1],
          authors: [pk],
        },
      ],
    );

    sub.on('event', event => {
      eventsRef.current.push(event);
      const sortedEvents = eventsRef.current.sort(function(x, y){
          return y.created_at - x.created_at;
      });
      eventsRef.current = sortedEvents;
    });

  },[]);

  useEffect(() => {
    setEvents(eventsRef.current);
  },[eventsRef])

  return({events,npub});
}

export default useNostr;
