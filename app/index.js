const path = require('path')
const cwd = process.cwd()
const logger = require('pino')({ level: process.env.LOG_LEVEL || 'info', prettyPrint: { translateTime: true } })
const fs = require('fs')
const HDWalletProvider = require('@truffle/hdwallet-provider')
const EthWallet = require('ethereumjs-wallet')
const Web3 = require('web3')

const configDir = path.join(cwd, process.env.CONFIG_DIR || 'config/')

let web3
let walletProvider
let account
let consensus, blockReward

function initWalletProvider() {
  logger.info(`initWalletProvider`)
  let keystoreDir = path.join(configDir, 'keys/FuseNetwork')
  let keystore
  fs.readdirSync(keystoreDir).forEach(file => {
    if (file.startsWith('UTC')) {
      keystore = fs.readFileSync(path.join(keystoreDir, file)).toString()
    }
  })
  let password = fs.readFileSync(path.join(configDir, 'pass.pwd')).toString().trim()
  let wallet = EthWallet.fromV3(keystore, password)
  let pkey = wallet.getPrivateKeyString()
  walletProvider = new HDWalletProvider({
          privateKeys: [pkey], 
          providerOrUrl: process.env.RPC,
          pollingInterval: 0})
  if (!walletProvider) {
    throw new Error(`Could not set walletProvider for unknown reason`)
  } else {
    account = wallet.getAddressString()
    logger.info(`account: ${account}`)
    web3 = new Web3(walletProvider)
  }
}

async function getNonce() {
  try {
    logger.debug(`getNonce for ${account}`)
    const transactionCount = await web3.eth.getTransactionCount(account)
    logger.debug(`transactionCount for ${account} is ${transactionCount}`)
    return transactionCount
  } catch (e) {
    throw new Error(`Could not get nonce`)
  }
}

async function getGasPrice() {
  try {
    logger.debug(`getGasPrice for ${account}`)
    const gasPrice = await web3.eth.getGasPrice()
    logger.debug(`current GasPrice is ${gasPrice}`)
    return Math.max(process.env.MIN_GAS_PRICE,gasPrice)
  } catch (e) {
    throw new Error(`Could not get gasPrice`)
  }
}

function initConsensusContract() {
  logger.info(`initConsensusContract`, process.env.CONSENSUS_ADDRESS)
  consensus = new web3.eth.Contract(require(path.join(cwd, 'abi/consensus')), process.env.CONSENSUS_ADDRESS)
}

function initBlockRewardContract() {
  logger.info(`initBlockRewardContract`, process.env.BLOCK_REWARD_ADDRESS)
  blockReward = new web3.eth.Contract(require(path.join(cwd, 'abi/blockReward')), process.env.BLOCK_REWARD_ADDRESS)
}

function emitInitiateChange() {
  return new Promise(async (resolve, reject) => {
    try {
      logger.info(`emitInitiateChange`)
      let currentBlockNumber = await web3.eth.getBlockNumber()
      let currentCycleEndBlock = (await consensus.methods.getCurrentCycleEndBlock.call()).toNumber()
      let shouldEmitInitiateChange = await consensus.methods.shouldEmitInitiateChange.call()
      logger.info(`block #${currentBlockNumber}\n\tcurrentCycleEndBlock: ${currentCycleEndBlock}\n\tshouldEmitInitiateChange: ${shouldEmitInitiateChange}`)
      if (!shouldEmitInitiateChange) {
        return resolve()
      }
      logger.info(`${account} sending emitInitiateChange transaction`)
      let nonce = await getNonce()
      let gasPrice = await getGasPrice()
      consensus.methods.emitInitiateChange().send({ from: account, gas: process.env.GAS || 1000000, gasPrice: process.env.GAS_PRICE || gasPrice, nonce: nonce })
        .on('transactionHash', hash => {
          logger.info(`transactionHash: ${hash}`)
        })
        .on('confirmation', (confirmationNumber, receipt) => {
          if (confirmationNumber == 1) {
            logger.debug(`receipt: ${JSON.stringify(receipt)}`)
          }
          resolve()
        })
        .on('error', error => {
          logger.error(error); resolve()
        })
    } catch (e) {
      reject(e)
    }
  })
}

function emitRewardedOnCycle() {
  return new Promise(async (resolve, reject) => {
    try {
      logger.info(`emitRewardedOnCycle`)
      let currentBlockNumber = await web3.eth.getBlockNumber()
      let currentCycleEndBlock = (await consensus.methods.getCurrentCycleEndBlock.call()).toNumber()
      let shouldEmitRewardedOnCycle = await blockReward.methods.shouldEmitRewardedOnCycle.call()
      logger.info(`block #${currentBlockNumber}\n\tcurrentCycleEndBlock: ${currentCycleEndBlock}\n\tshouldEmitRewardedOnCycle: ${shouldEmitRewardedOnCycle}`)
      if (!shouldEmitRewardedOnCycle) {
        return resolve()
      }
      logger.info(`${account} sending emitRewardedOnCycle transaction`)
      let nonce = await getNonce()
      let gasPrice = await getGasPrice()
      blockReward.methods.emitRewardedOnCycle().send({ from: account, gas: process.env.GAS || 1000000, gasPrice: process.env.GAS_PRICE || gasPrice, nonce: nonce })
        .on('transactionHash', hash => {
          logger.info(`transactionHash: ${hash}`)
        })
        .on('confirmation', (confirmationNumber, receipt) => {
          if (confirmationNumber == 1) {
            logger.debug(`receipt: ${JSON.stringify(receipt)}`)
          }
          resolve()
        })
        .on('error', error => {
          logger.error(error); resolve()
        })
    } catch (e) {
      reject(e)
    }
  })
}

async function runMain() {
  try {
    logger.info(`runMain`)
    if (!walletProvider) {
      initWalletProvider()
    }
    if (!consensus) {
      initConsensusContract()
    }
    if (!blockReward) {
      initBlockRewardContract()
    }
    const isValidator = await consensus.methods.isValidator(web3.utils.toChecksumAddress(account)).call()
    if (!isValidator) {
      logger.warn(`${account} is not a validator, skipping`)
      return
    }
    await emitInitiateChange()
    await emitRewardedOnCycle()
  } catch (e) {
    logger.error(e)
    process.exit(1)
  }

  setTimeout(() => {
    runMain()
  }, process.env.POLLING_INTERVAL || 2500)
}

runMain()