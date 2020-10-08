require('dotenv').config()
const fs = require('fs')

const EternalStorageProxy = artifacts.require('./eternal-storage/EternalStorageProxy.sol')
const BlockReward = artifacts.require('./BlockReward.sol')
const Consensus = artifacts.require('./Consensus.sol')
const ProxyStorage = artifacts.require('./ProxyStorage.sol')
const Voting = artifacts.require('./Voting.sol')

const {toBN, toWei} = web3.utils

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const {
  INITIAL_VALIDATOR_ADDRESS,
  INITIAL_SUPPLY_GWEI,
  SAVE_TO_FILE,
  DEBUG
} = process.env

const debug = msg => { if (DEBUG) console.log(msg) }

module.exports = function(deployer, network, accounts) {
  if (network !== 'test') {
    let initialValidatorAddress = INITIAL_VALIDATOR_ADDRESS || ZERO_ADDRESS
    let initialSupply = toWei(toBN(INITIAL_SUPPLY_GWEI || 0), 'gwei')

    let proxy
    let blockReward, blockRewardImpl
    let consensus, consensusImpl
    let proxyStorage, proxyStorageImpl
    let voting, votingImpl

    deployer.then(async function() {
      /*
      // In case the consensus implementation fails to deploy with truffle,
      // use other tool like remix and put the address here in the following way:
      consensusImpl = {
        address: '0x789b5f79EAd29C4dc39b22C12602D59f6c613e4C'
      }
      */

      // Consensus
      consensusImpl = await Consensus.new()
      debug(`consensusImpl: ${consensusImpl.address}`)
      proxy = await EternalStorageProxy.new(ZERO_ADDRESS, consensusImpl.address)
      debug(`proxy: ${proxy.address}`)
      consensus = await Consensus.at(proxy.address)
      debug(`consensus: ${consensus.address}`)
      await consensus.initialize(initialValidatorAddress)
      debug(`consensus.initialize: ${initialValidatorAddress}`)

      // ProxyStorage
      proxyStorageImpl = await ProxyStorage.new()
      debug(`proxyStorageImpl: ${proxyStorageImpl.address}`)
      proxy = await EternalStorageProxy.new(ZERO_ADDRESS, proxyStorageImpl.address)
      debug(`proxy: ${proxy.address}`)
      proxyStorage = await ProxyStorage.at(proxy.address)
      debug(`proxyStorage: ${proxyStorage.address}`)
      await proxyStorage.initialize(consensus.address)
      debug(`proxyStorage.initialize: ${consensus.address}`)
      await consensus.setProxyStorage(proxyStorage.address)
      debug(`consensus.setProxyStorage: ${proxyStorage.address}`)

      // BlockReward
      blockRewardImpl = await BlockReward.new()
      debug(`blockRewardImpl: ${blockRewardImpl.address}`)
      proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
      debug(`proxy: ${proxy.address}`)
      blockReward = await BlockReward.at(proxy.address)
      debug(`blockReward: ${blockReward.address}`)
      await blockReward.initialize(initialSupply)
      debug(`blockReward.initialize: ${initialSupply}`)

      // Voting
      votingImpl = await Voting.new()
      debug(`votingImpl: ${votingImpl.address}`)
      proxy = await EternalStorageProxy.new(proxyStorage.address, votingImpl.address)
      debug(`proxy: ${proxy.address}`)
      voting = await Voting.at(proxy.address)
      debug(`voting: ${voting.address}`)
      await voting.initialize()
      debug(`voting.initialize`)

      // Initialize ProxyStorage
      await proxyStorage.initializeAddresses(blockReward.address, voting.address)
      debug(`proxyStorage.initializeAddresses: ${blockReward.address}, ${voting.address}`)

      if (!!SAVE_TO_FILE === true) {
        const contracts = {
          "BlockReward": blockReward.address,
          "Consensus": consensus.address,
          "ProxyStorage": proxyStorage.address,
          "Voting": voting.address
        }
        fs.writeFileSync('./contracts.json', JSON.stringify(contracts, null, 2));
      }

      console.log(
        `
        Block Reward implementation ...................... ${blockRewardImpl.address}
        Block Reward storage ............................. ${blockReward.address}
        Consensus implementation ......................... ${consensusImpl.address}
        Consensus storage ................................ ${consensus.address}
        ProxyStorage implementation ...................... ${proxyStorageImpl.address}
        ProxyStorage storage ............................. ${proxyStorage.address}
        Voting implementation ............................ ${votingImpl.address}
        Voting storage ................................... ${voting.address}
        `
      )
    }).catch(function(error) {
      console.error(error)
    })
  }
}
