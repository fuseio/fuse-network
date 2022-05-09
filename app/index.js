const path = require('path')
const cwd = process.cwd()
const logger = require('pino')({ level: process.env.LOG_LEVEL || 'info', prettyPrint: { translateTime: true } })
const fs = require('fs')
const HDWalletProvider = require('truffle-hdwallet-provider')
const EthWallet = require('ethereumjs-wallet')
const Web3 = require('web3')
const ethers = require('ethers')
const { sign, signFuse } = require('./utils')

const configDir = path.join(cwd, process.env.CONFIG_DIR || 'config/')

const {ETH_RPC, BSC_RPC, RPC: FUSE_RPC} = process.env

let web3
let walletProvider
let account
let consensus, blockReward, blockRegistry
let blockchains = {}

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
  }
}
function initBlockchain(chainId, rpc) {
  logger.info('initBlockchain')
  try {
    blockchains[chainId] = {
      account: walletProvider.addresses[0],
      web3: new Web3(walletProvider),
      rpc,
      signer: new ethers.Wallet(pkey),
      blocks: {},
    }
    blockchains[chainId].web3.eth.subscribe('newBlockHeaders', async (block) => {
      try {
        if (chainId == 122) {
          let cycleEnd = (await consensus.methods.getCurrentCycleEndBlock.call()).toNumber()
          let validators = await consensus.methods.currentValidators().call()
          const numValidators = validators.length
          blockchains[chainId].blocks[block.hash] = await signFuse(block, chainId, blockchain.provider, blockchain.signer, cycleEnd, validators)
        }
        else {
          blockchains[chainId].blocks[block.hash] = await sign(block, chainId, blockchain.provider, blockchain.signer)
        }
      } catch(e) {
        logger.error(`newBlockHeaders: ${e.toString()}`)
      }
    })
  } catch(e) {
    throw `initBlockchain(${chainId}, ${rpc}) failed: ${e.toString()}`
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
  initBlockchain(1, process.env.ETH_RPC || throw "Missing ETH_RPC in environment")
  initBlockchain(56, process.env.BSC_RPC || throw "Missing BSC_RPC in environment"))
  initBlockchain(122, process.env.FUSE_RPC || 'https://rpc.fuse.io/')
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

async function emitRegistry() {
  try {
    logger.info('emitRegistry')
    const currentBlock = (await web3.eth.getBlockNumber()).toNumber()
    const chains = await blockRegistry.methods.getRpcs.call()
    await Promise.all(chains.filter(chain => !blockchains[chain[0]] || blockchains[chain[0]].rpc != chain[1]).map(async (chain) => initBlockchain(...chain)))
    const blocks = {}
    const chainIds = {}
    Object.entries(blockchains).forEach((chainId, blockchain) => {
      Object.entries(blockchain.blocks).forEach((hash, signed) => {
        blocks[hash] = signed
        chainIds[hash] = chainId
        delete blockchain.blocks[hash]
      })
    })
  } catch(e) {
    throw `emitRegistry failed trying to update rpcs`
  }
  try {
    const receipt = await blockRegistry.methods.addSignedBlocks(Object.values(blocks)).send({ from: account })
    logger.info(`transactionHash: ${receipt.transactionHash}`)
    logger.debug(`receipt: ${JSON.stringify(receipt)}`)
  } catch(e) {
    if (!e.data) throw e
    else {
      logger.error(e)
      const data = e.data;
      const txHash = Object.keys(data)[0];
      const reason = data[txHash].reason;
      Object.entries(blocks).filter((hash, signed) => hash != reason).forEach((hash, signed) => blockchains[chainIds[hash]].blocks[hash] = signed)
    }
  }
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
    await emitRegistry()
  } catch (e) {
    logger.error(e)
    process.exit(1)
  }

  setTimeout(() => {
    runMain()
  }, process.env.POLLING_INTERVAL || 2500)
}

runMain()
