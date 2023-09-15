import express from 'express';
import request from 'request';
import https from 'https';
import fs from 'fs';
import * as dotenv from 'dotenv';
dotenv.config();
const app = express();

const privateKey = fs.readFileSync( 'tls/privatekey.pem' );
const certificate = fs.readFileSync( 'tls/certificate.pem' );

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


https.createServer({
    key: privateKey,
    cert: certificate
}, app).listen(8085,() => {
  console.log("Service initiated at port 8085")
});
