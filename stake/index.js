require("dotenv").config();
console.log(process.env); // remove this after you've confirmed it working
const path = require("path");
const cwd = process.cwd();
const logger = require("pino")({
  level: process.env.LOG_LEVEL || "info",
  prettyPrint: { translateTime: true },
});
const fs = require("fs");
const { ethers } = require("ethers");
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC);
const addressReceiver = process.env.CONSENSUS_ADDRESS;

const configDir = path.join(cwd, process.env.CONFIG_DIR || "config/");

let web3;
let balance;

async function initWalletProvider() {
  logger.info(`initWalletProvider`);
  let keystoreDir = path.join(configDir, "keys/FuseNetwork");
  let keystore;
  fs.readdirSync(keystoreDir).forEach((file) => {
    if (file.startsWith("UTC")) {
      keystore = fs.readFileSync(path.join(keystoreDir, file)).toString();
    }
  });
  let password = fs
    .readFileSync(path.join(configDir, "pass.pwd"))
    .toString()
    .trim();
  let wallet = await ethers.Wallet.fromEncryptedJson(keystore, password);
  web3 = wallet.connect(provider);
  if (!web3) {
    throw new Error(`Could not connect wallet for unknown reason`);
  }
  balance = await provider.getBalance(web3.address);
  logger.info(`balance: ${ethers.utils.formatEther(balance)}`);
}

async function sendStake() {
  balance = await provider.getBalance(web3.address);
  logger.info(`balance: ${ethers.utils.formatEther(balance)}`);
  const txBuffer = ethers.utils.parseEther(".005");
  if (balance.sub(txBuffer) > 0) {
    console.log("NEW ARRIVAL OF FUSE!");
    const amount = balance.sub(txBuffer);
    try {
      const tx = await web3.sendTransaction({
        to: addressReceiver,
        value: amount,
      });
      console.log(
        `Starting transfer of --> ${ethers.utils.formatEther(amount)}`
      );
      await tx.wait();
      console.log(`Success! tx hash  --> ${tx.transactionHash}`);
    } catch (e) {
      console.log(`error: ${e}`);
    }
  }
}

async function runMain() {
  try {
    logger.info(`runMain`);
    if (!web3) {
      await initWalletProvider();
    }
    await sendStake();
  } catch (e) {
    logger.error(e);
    process.exit(1);
  }

  setTimeout(() => {
    runMain();
  }, process.env.POLLING_INTERVAL || 2500);
}

runMain();
