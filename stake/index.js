const path = require("path");
const cwd = process.cwd();
const logger = require("pino")({
  level: process.env.LOG_LEVEL || "info",
  prettyPrint: { translateTime: true },
});
const fs = require("fs");
const { ethers } = require("ethers");
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC);
const addressReceiver = process.env.RECEIVER_ADDRESS;

const configDir = path.join(cwd, process.env.CONFIG_DIR || "config/");

let web3;
let consensus, blockReward;

function initWalletProvider() {
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
  const balance = await provider.getBalance(web3.address);
  logger.info(`balance: ${ethers.utils.formatEther(balance)}`);
  const txBuffer = ethers.utils.parseEther(".005");
  if (balance.sub(txBuffer) > 0) {
    console.log("NEW ACCOUNT WITH ETH!");
    const amount = balance.sub(txBuffer);
    try {
      await web3.sendTransaction({
        to: addressReceiver,
        value: amount,
      });
      console.log(
        `Success! transfered --> ${ethers.utils.formatEther(balance)}`
      );
    } catch (e) {
      console.log(`error: ${e}`);
    }
  }
}

function initConsensusContract() {
  logger.info(`initConsensusContract`, process.env.CONSENSUS_ADDRESS);
  consensus = new web3.eth.Contract(
    require(path.join(cwd, "abi/consensus")),
    process.env.CONSENSUS_ADDRESS
  );
}

function initBlockRewardContract() {
  logger.info(`initBlockRewardContract`, process.env.BLOCK_REWARD_ADDRESS);
  blockReward = new web3.eth.Contract(
    require(path.join(cwd, "abi/blockReward")),
    process.env.BLOCK_REWARD_ADDRESS
  );
}

async function runMain() {
  try {
    logger.info(`runMain`);
    if (!walletProvider) {
      initWalletProvider();
    }
    if (!consensus) {
      initConsensusContract();
    }
    if (!blockReward) {
      initBlockRewardContract();
    }
    await emitInitiateChange();
    await emitRewardedOnCycle();
  } catch (e) {
    logger.error(e);
    process.exit(1);
  }

  setTimeout(() => {
    runMain();
  }, process.env.POLLING_INTERVAL || 2500);
}

runMain();
