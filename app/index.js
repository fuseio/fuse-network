const path = require('path')
const cwd = process.cwd()
const logger = require('pino')({ level: process.env.LOG_LEVEL || 'info', prettyPrint: { translateTime: true } })
const fs = require('fs')
const HDWalletProvider = require('truffle-hdwallet-provider')
const EthWallet = require('ethereumjs-wallet')
const Web3 = require('web3')

const configDir = path.join(cwd, process.env.CONFIG_DIR || 'config/')

let web3
let walletProvider
let account
let consensus

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

function initConsensusContract() {
  logger.info(`initConsensusContract`, process.env.CONSENSUS_ADDRESS)
  consensus = new web3.eth.Contract(require(path.join(cwd, 'abi/consensus')), process.env.CONSENSUS_ADDRESS)
}

function emitInitiateChange() {
  return new Promise(async (resolve, reject) => {
    logger.info(`emitInitiateChange`)
    let currentBlockNumber = await web3.eth.getBlockNumber()
    let currentCycleEndBlock = await consensus.methods.getCurrentCycleEndBlock.call()
    let shouldEmitInitiateChange = await consensus.methods.shouldEmitInitiateChange.call()
    logger.info(`block #${currentBlockNumber}\n\tcurrentCycleEndBlock: ${currentCycleEndBlock}\n\tshouldEmitInitiateChange: ${shouldEmitInitiateChange}`)
    if (shouldEmitInitiateChange) {
      let nonce = await web3.eth.getTransactionCount(account)
      logger.debug(`nonce: ${nonce}`)
      consensus.methods.emitInitiateChange().send({
        from: account,
        gasPrice: 0
      })
      .on('transactionHash', hash => {
        logger.debug(`transactionHash: ${hash}`)
      })
      .on('confirmation', (confirmationNumber, receipt) => {
        if (confirmationNumber == 1) {
          logger.debug(`receipt: ${JSON.stringify(receipt)}`)
        }
        resolve()
      })
      .on('error', error => {
        logger.error(`error: ${error}`)
        resolve()
      })
    } else {
      resolve()
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
    await emitInitiateChange()
  } catch (e) {
    logger.error(e)
  }

  setTimeout(() => {
    runMain()
  }, process.env.POLLING_INTERVAL || 5000)
}

runMain()
