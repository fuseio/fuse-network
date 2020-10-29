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
      // Consensus

      const voting = {
        address: '0x4c889f137232E827c00710752E86840805A70484'
      }

      const consensus = {
        address: '0x3014ca10b91cb3D0AD85fEf7A3Cb95BCAc9c0f79'
      }
      // ProxyStorage
      proxyStorageImpl = await ProxyStorage.new()
      debug(`proxyStorageImpl: ${proxyStorageImpl.address}`)
      proxy = await EternalStorageProxy.new(ZERO_ADDRESS, proxyStorageImpl.address)
      debug(`proxy: ${proxy.address}`)
      proxyStorage = await ProxyStorage.at(proxy.address)
      debug(`proxyStorage: ${proxyStorage.address}`)
      await proxyStorage.initialize(consensus.address)
      debug(`proxyStorage.initialize: ${consensus.address}`)
      // await consensus.setProxyStorage(proxyStorage.address)
      // debug(`consensus.setProxyStorage: ${proxyStorage.address}`)

      // BlockReward
      blockRewardImpl = await BlockReward.new()
      debug(`blockRewardImpl: ${blockRewardImpl.address}`)
      proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
      debug(`proxy: ${proxy.address}`)
      blockReward = await BlockReward.at(proxy.address)
      debug(`blockReward: ${blockReward.address}`)
      await blockReward.initialize(initialSupply)
      debug(`blockReward.initialize: ${initialSupply}`)

      // Initialize ProxyStorage
      await proxyStorage.initializeAddresses(blockReward.address, voting.address)
      debug(`proxyStorage.initializeAddresses: ${blockReward.address}, ${voting.address}`)

      // TODO:
      // stake to consensus on behalf of the initial validator
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
        Consensus storage ................................ ${consensus.address}
        ProxyStorage implementation ...................... ${proxyStorageImpl.address}
        ProxyStorage storage ............................. ${proxyStorage.address}
        Voting storage ................................... ${voting.address}
        `
      )
    }).catch(function(error) {
      console.error(error)
    })
  }
}
