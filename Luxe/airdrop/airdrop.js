// find the json file
let inputList = require('./result.json');

const TronWeb = require("tronweb")
const async = require("async");
let env = {
    PRIVATE_KEYS: "HERE GOES YOUR PRIVATE KEY",
    NETWORK: "https://api.trongrid.io"
}
let tronWeb = new TronWeb({
    fullHost: env.NETWORK,
    privateKey: env.PRIVATE_KEYS
})
function writeinFiles(successfulList, rejectedList) {
    var fs = require('fs');
    let success = JSON.stringify(successfulList);
    let rejected = JSON.stringify(rejectedList);
    fs.writeFile('successful.json', success, 'utf8', (res) => { console.log(res) });
    fs.writeFile('rejected.json', rejected, 'utf8', (res) => { console.log(res) });
}
// call the function

let txs = [];
let rejectedList = [];
let successfulList = [];

async function transfer() {
    let tronWeb = await new TronWeb({
        fullHost: env.NETWORK,
        privateKey: env.PRIVATE_KEYS
    })
    const tokenContract = "HERE GOES YOUR DAPPSTAT TOKEN CONTRACT ADDRESS";
    let contract = await tronWeb.contract().at(tokenContract);

    for (let i = 0; i < inputList.length; i++) {
        var element = inputList[i];
        try {
            var res = await contract.transfer(element.address, element.balance).send();
            txs.push({ tx: res, element: element });
        } catch (error) {
            console.log("error initially");
            rejectedList.push(element);
        }
    }
}

async function fetchResults() {
    let a = 0;
    for (let i = 0; i < txs.length; i++) {
        try {
            var element = txs[i].element;
            element.txhash = txs[i].tx;
            var tx = await tronWeb.trx.getTransaction(txs[i].tx);
            console.log(a++);
            if (tx.ret[0].contractRet === "SUCCESS") {
                successfulList.push(element);
                if (i + 1 == txs.length) {
                    writeinFiles(successfulList, rejectedList);
                }
            }
            else {

                element.txhash = txs[i].tx;
                rejectedList.push(element);
                if (i + 1 == txs.length) {
                    writeinFiles(successfulList, rejectedList);
                }
            }
        } catch (error) {
            element.txhash = txs[i].tx;
            rejectedList.push(element);
            if (i + 1 == txs.length) {
                writeinFiles(successfulList, rejectedList);
            }
        }

    }

}

function nextFunc(){
    setTimeout(fetchResults, 30000);
}
async.series([
    transfer,
    nextFunc
], function (err, results) {
    console.log(results);
});