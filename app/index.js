const path = require('path')
const cwd = process.cwd()
const logger = require('pino')({ level: process.env.LOG_LEVEL || 'info', prettyPrint: { translateTime: true } })
const fs = require('fs')
const HDWalletProvider = require('truffle-hdwallet-provider')
const EthWallet = require('ethereumjs-wallet')
const Web3 = require('web3')
const { emitRegistry } = require('./block-header-registry')
const configDir = path.join(cwd, process.env.CONFIG_DIR || 'config/')

const {ETH_RPC, BSC_RPC, RPC: FUSE_RPC} = process.env

let web3
let walletProvider, signer
let account
let consensus, blockReward, blockRegistry

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
  walletProvider = new HDWalletProvider(pkey, process.env.RPC)
  if (!walletProvider) {
    throw new Error(`Could not set walletProvider for unknown reason`)
  } else {
    account = walletProvider.addresses[0]
    logger.info(`account: ${account}`)
    web3 = new Web3(walletProvider)
    signer = new ethers.Wallet(pkey)
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

function initConsensusContract() {
  logger.info(`initConsensusContract`, process.env.CONSENSUS_ADDRESS)
  consensus = new web3.eth.Contract(require(path.join(cwd, 'abi/consensus')), process.env.CONSENSUS_ADDRESS)
}

function initBlockRewardContract() {
  logger.info(`initBlockRewardContract`, process.env.BLOCK_REWARD_ADDRESS)
  blockReward = new web3.eth.Contract(require(path.join(cwd, 'abi/blockReward')), process.env.BLOCK_REWARD_ADDRESS)
}

function initBlockRegistryContract() {
  logger.info(`initBlockRegistryContract`, process.env.BLOCK_REGISTRY_ADDRESS)
  blockRegistry = new web3.eth.Contract(require(path.join(cwd, 'abi/blockRegistry')), process.env.BLOCK_REGISTRY_ADDRESS)
  if (!ETH_RPC) throw "Missing ETH_RPC in environment"
  if (!BSC_RPC) throw "Missing BSC_RPC in environment"
  initBlockchain(1, ETH_RPC)
  initBlockchain(56, BSC_RPC)
  initBlockchain(122, FUSE_RPC || 'https://rpc.fuse.io/')
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
      consensus.methods.emitInitiateChange().send({ from: account, gas: process.env.GAS || 1000000, gasPrice: process.env.GAS_PRICE || '0', nonce: nonce })
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
      blockReward.methods.emitRewardedOnCycle().send({ from: account, gas: process.env.GAS || 1000000, gasPrice: process.env.GAS_PRICE || '0', nonce: nonce })
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
    if (!blockRegistry) {
      initBlockRegistryContract()
    }
    const isValidator = await consensus.methods.isValidator(web3.utils.toChecksumAddress(account)).call()
    if (!isValidator) {
      logger.warn(`${account} is not a validator, skipping`)
      return
    }
    await emitInitiateChange()
    await emitRewardedOnCycle()
    await emitRegistry({
      web3,
      consensus,
      blockRegistry,
      signer,
      walletProvider
    })
  } catch (e) {
    logger.error(e)
    process.exit(1)
  }

  setTimeout(() => {
    runMain()
  }, process.env.POLLING_INTERVAL || 2500)
}

runMain()
