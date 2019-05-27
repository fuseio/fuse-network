require('dotenv').config()

const EternalStorageProxy = artifacts.require('./eternal-storage/EternalStorageProxy.sol')
const BallotsStorage = artifacts.require('./BallotsStorage.sol')
const BlockReward = artifacts.require('./BlockReward.sol')
const Consensus = artifacts.require('./Consensus.sol')
const ProxyStorage = artifacts.require('./ProxyStorage.sol')
const VotingToChangeBlockReward = artifacts.require('./VotingToChangeBlockReward.sol')
const VotingToChangeMinStake = artifacts.require('./VotingToChangeMinStake.sol')
const VotingToChangeMinThreshold = artifacts.require('./VotingToChangeMinThreshold.sol')
const VotingToChangeProxyAddress = artifacts.require('./VotingToChangeProxyAddress.sol')

const {toBN, toWei} = web3.utils

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const {
  CONSENSUS_ADDRESS,
  INITIAL_VALIDATOR_ADDRESS,
  MIN_STAKE_GWEI,
  BLOCK_REWARD_GWEI,
  BALLOT_THRESHOLDS,
  MIN_BALLOT_DURATION_SECONDS,
  MIN_POSSIBLE_BLOCK_REWARD_GWEI,
  MIN_POSSIBLE_STAKE_GWEI,
  MIN_POSSIBLE_THRESHOLD,
  SAVE_TO_FILE
} = process.env

module.exports = function(deployer, network, accounts) {
  if (network !== 'test') {
    let initialValidatorAddress = INITIAL_VALIDATOR_ADDRESS || ZERO_ADDRESS
    let minStake = toWei(toBN(MIN_STAKE_GWEI || 0), 'gwei')
    let blockRewardAmount = toWei(toBN(BLOCK_REWARD_GWEI || 0), 'gwei')
    let minBallotDuration = MIN_BALLOT_DURATION_SECONDS || 172800
    let minPossibleBlockReward = toWei(toBN(MIN_POSSIBLE_BLOCK_REWARD_GWEI || 0), 'gwei')
    let minPossibleStake = toWei(toBN(MIN_POSSIBLE_STAKE_GWEI || 0), 'gwei')
    let minPossibleThreshold = MIN_POSSIBLE_THRESHOLD || 3
    let ballotsThresholds = [minPossibleThreshold, minPossibleBlockReward, minPossibleStake]
    if (BALLOT_THRESHOLDS) {
      let arr = BALLOT_THRESHOLDS.split(',')
      ballotsThresholds = [
        arr[0],
        toWei(toBN(arr[1]), 'gwei'),
        toWei(toBN(arr[2]), 'gwei')
      ]
    }

    let proxy
    let ballotsStorage, ballotsStorageImpl
    let blockReward, blockRewardImpl
    let consensus, consensusImpl
    let proxyStorage, proxyStorageImpl
    let votingToChangeBlockReward, votingToChangeBlockRewardImpl
    let votingToChangeMinStake, votingToChangeMinStakeImpl
    let votingToChangeMinThreshold, votingToChangeMinThresholdImpl
    let votingToChangeProxy, votingToChangeProxyImpl

    deployer.then(async function() {
      // Consensus
      consensusImpl = await Consensus.new()
      proxy = await EternalStorageProxy.new(ZERO_ADDRESS, consensusImpl.address)
      consensus = await Consensus.at(proxy.address)
      await consensus.initialize(minStake, initialValidatorAddress)

      // ProxyStorage
      proxyStorageImpl = await ProxyStorage.new()
      proxy = await EternalStorageProxy.new(ZERO_ADDRESS, proxyStorageImpl.address)
      proxyStorage = await ProxyStorage.at(proxy.address)
      await proxyStorage.initialize(consensus.address)
      await consensus.setProxyStorage(proxyStorage.address)

      // BallotsStorage
      ballotsStorageImpl = await BallotsStorage.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, ballotsStorageImpl.address)
      ballotsStorage = await BallotsStorage.at(proxy.address)
      ballotsStorage.initialize(ballotsThresholds)

      // BlockReward
      blockRewardImpl = await BlockReward.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
      blockReward = await BlockReward.at(proxy.address)
      await blockReward.initialize(blockRewardAmount)

      // VotingToChangeBlockReward
      votingToChangeBlockRewardImpl = await VotingToChangeBlockReward.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, votingToChangeBlockRewardImpl.address)
      votingToChangeBlockReward = await VotingToChangeBlockReward.at(proxy.address)
      await votingToChangeBlockReward.initialize(minBallotDuration, minPossibleBlockReward)

      // VotingToChangeMinStake
      votingToChangeMinStakeImpl = await VotingToChangeMinStake.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, votingToChangeMinStakeImpl.address)
      votingToChangeMinStake = await VotingToChangeMinStake.at(proxy.address)
      await votingToChangeMinStake.initialize(minBallotDuration, minPossibleStake)

      // VotingToChangeMinThreshold
      votingToChangeMinThresholdImpl = await VotingToChangeMinThreshold.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, votingToChangeMinThresholdImpl.address)
      votingToChangeMinThreshold = await VotingToChangeMinThreshold.at(proxy.address)
      await votingToChangeMinThreshold.initialize(minBallotDuration, minPossibleThreshold)

      // VotingToChangeProxyAddress
      votingToChangeProxyImpl = await VotingToChangeProxyAddress.new()
      proxy = await EternalStorageProxy.new(proxyStorage.address, votingToChangeProxyImpl.address)
      votingToChangeProxy = await VotingToChangeProxyAddress.at(proxy.address)
      await votingToChangeProxy.initialize(minBallotDuration)

      // Initialize ProxyStorage
      await proxyStorage.initializeAddresses(
        blockReward.address,
        ballotsStorage.address,
        votingToChangeBlockReward.address,
        votingToChangeMinStake.address,
        votingToChangeMinThreshold.address,
        votingToChangeProxy.address
      )

      if (!!SAVE_TO_FILE === true) {
        const contracts = {
          "BallotsStorage": ballotsStorage.address,
          "BlockReward": blockReward.address,
          "Consensus": consensus.address,
          "ProxyStorage": proxyStorage.address,
          "VotingToChangeBlockReward": votingToChangeBlockReward.address,
          "VotingToChangeMinStake": votingToChangeMinStake.address,
          "VotingToChangeMinThreshold": votingToChangeMinThreshold.address,
          "VotingToChangeProxy": votingToChangeProxy.address
        }
        fs.writeFileSync('./contracts.json', JSON.stringify(contracts, null, 2));
      }

      console.log(
        `
        BallotsStorage implementation..................... ${ballotsStorageImpl.address}
        BallotsStorage storage ........................... ${ballotsStorage.address}
        Block Reward implementation ...................... ${blockRewardImpl.address}
        Block Reward storage ............................. ${blockReward.address}
        Consensus implementation ......................... ${consensusImpl.address}
        Consensus storage ................................ ${consensus.address}
        ProxyStorage implementation ...................... ${proxyStorageImpl.address}
        ProxyStorage storage ............................. ${proxyStorage.address}
        VotingToChangeBlockReward implementation ......... ${votingToChangeBlockRewardImpl.address}
        VotingToChangeBlockReward storage ................ ${votingToChangeBlockReward.address}
        VotingToChangeMinStake implementation ............ ${votingToChangeMinStakeImpl.address}
        VotingToChangeMinStake storage ................... ${votingToChangeMinStake.address}
        VotingToChangeMinThreshold implementation ........ ${votingToChangeMinThresholdImpl.address}
        VotingToChangeMinThreshold storage ............... ${votingToChangeMinThreshold.address}
        VotingToChangeProxyAddress implementation ........ ${votingToChangeProxyImpl.address}
        VotingToChangeProxyAddress storage ............... ${votingToChangeProxy.address}
        `
      )
    }).catch(function(error) {
      console.error(error)
    })
  }
}
