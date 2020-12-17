"use strict";
//const request = require("request");
const fs = require("fs");
const config = require("../../configs/config");
var moment = require("moment");
const signMessage = require("./signMessage");
// let gethWebsocketUrl = config.geth.gethWebsocketUrl;
// const Web3 = require("web3");
// // use the given Provider, e.g in Mist, or instantiate a new websocket provider
// const web3 = new Web3(Web3.givenProvider || gethWebsocketUrl);
const { Base64 } = require("js-base64");

module.exports = async function createDID(data) {
  let now_timestamp = new Date().getTime();
  let now = Math.floor(now_timestamp / 1000);
  //let now_timestamp = Math.floor(dateTime / 1000);
  //let Registry_Abi = config.DIDRegistry.abi;
  let nowAccount = data.account;
  let _identity = data.identity;
  let url = `http://localhost:3001/DIDDocument/?did=${_identity}`;
  let expire_time = now + config.did.expire * 31536000;
  let randomID = Math.floor(Math.random() * 1000000) + 1;
  let _nonce = (Math.floor(Math.random() * 10000) + 1).toString();
  //let _signature = `fafsa`;
  let _signature = await signMessage(config.did.issuer, _identity, _nonce);

  let did_info = {
    "@context": config.did.context,
    id: _identity,
    issuer: `did:${config.did.method}:${config.did.issuer}`,
    publicKey: [
      {
        id: `did:${config.did.method}:${_identity}#controller`,
        type: config.did.publicKey.type,
        controller: `did:${config.did.method}:${_identity}`,
        ethereumAddress: nowAccount
      }
    ],
    claim: {
      staffID: randomID,
      allowenceStatus: 1,
      expire: expire_time
    },
    signautre: [
      {
        type: config.did.signature.type,
        publicKey: `did:${config.did.method}:${config.did.issuer}`,
        nonce: _nonce,
        signaturevalue: _signature
      }
    ]
  };

  return new Promise((resolve, reject) => {
    let result = {};
    result.url = url;
    result.document = did_info;
    result.status = true;
    let data = JSON.stringify(result.document);
    fs.writeFileSync(`./DID_storage/${_identity}.json`, data);
    resolve(result);
  });
};
