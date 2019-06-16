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
  CONSENSUS_ADDRESS,
  INITIAL_VALIDATOR_ADDRESS,
  MIN_STAKE_GWEI,
  CYCLE_DURATION_BLOCKS,
  SNAPSHOTS_PER_CYCLE,
  BLOCK_REWARD_GWEI,
  MIN_BALLOT_DURATION_CYCLES,
  SAVE_TO_FILE
} = process.env

module.exports = function(deployer, network, accounts) {
  if (network !== 'test') {
    let initialValidatorAddress = INITIAL_VALIDATOR_ADDRESS || ZERO_ADDRESS
    let minStake = toWei(toBN(MIN_STAKE_GWEI || 0), 'gwei')
    let cycleDurationBlocks = CYCLE_DURATION_BLOCKS || 17280
    let snapshotsPerCycle = SNAPSHOTS_PER_CYCLE || 10
    let blockRewardAmount = toWei(toBN(BLOCK_REWARD_GWEI || 0), 'gwei')
    let minBallotDurationCycles = MIN_BALLOT_DURATION_CYCLES || 2

    let proxy
    let blockReward, blockRewardImpl
    let consensus, consensusImpl
    let proxyStorage, proxyStorageImpl
    let voting, votingImpl

    deployer.then(async function() {
      // Consensus
      consensusImpl = await Consensus.new()
      proxy = await EternalStorageProxy.new(ZERO_ADDRESS, consensusImpl.address)
      consensus = await Consensus.at(proxy.address)
      await consensus.initialize(minStake, cycleDurationBlocks, snapshotsPerCycle, initialValidatorAddress)

      // ProxyStorage
      proxyStorageImpl = await ProxyStorage.new()
      proxy = await EternalStorageProxy.new(ZERO_ADDRESS, proxyStorageImpl.address)
      proxyStorage = await ProxyStorage.at(proxy.address)
      await proxyStorage.initialize(consensus.address)
      await consensus.setProxyStorage(proxyStorage.address)

      // BlockReward
      blockRewardImpl = await BlockReward.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
      blockReward = await BlockReward.at(proxy.address)
      await blockReward.initialize(blockRewardAmount)

      // Voting
      votingImpl = await Voting.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, votingImpl.address)
      voting = await Voting.at(proxy.address)
      await voting.initialize(minBallotDurationCycles)

      // Initialize ProxyStorage
      await proxyStorage.initializeAddresses(
        blockReward.address,
        voting.address
      )

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
