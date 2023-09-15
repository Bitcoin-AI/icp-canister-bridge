import express from 'express';
import request from 'request';
import https from 'https';
import fs from 'fs';
import {ethers} from 'ethers'
import * as dotenv from 'dotenv';

dotenv.config();
const app = express();


// Test Route
app.get('/', (req, res) => {
  let options = {
    url: `https://${process.env.REST_HOST}/v1/getinfo`,
    // Work-around for self-signed certificates.
    rejectUnauthorized: false,
    json: true,
    headers: {
      'Grpc-Metadata-macaroon': process.env.MACAROON_HEX,
    },
  }
  request.get(options, function(error, response, body) {
    res.json(body)
  });
});


// Post to pay invoice to user, verify conditions firts (must come from canister)
app.post('/', (req, res) => {


  // Verify if request comes from icp canister
  const signature = req.header.signature;
  const message = req.body.payment_request;

  const address = ethers.utils.verifyMessage( message , signature );

  if(address != process.env.CANISTER_ADDRESS){
    res.send("Invalid signature");
  }

  let options = {
    url: `https://${process.env.REST_HOST}/v2/router/send`,
    // Work-around for self-signed certificates.
    rejectUnauthorized: false,
    json: true,
    headers: {
      'Grpc-Metadata-macaroon': process.env.MACAROON_HEX,
    },
    body: JSON.stringify(
      {
        payment_request: req.body.payment_request
      }
    ),
  }
  request.post(options, function(error, response, body) {
    res.json(body);
  });
});


app.listen(8085,() => {
  console.log("Service initiated at port 8085")
});
