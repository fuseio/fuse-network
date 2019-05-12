require('dotenv').config()
const Consensus = artifacts.require('./Consensus.sol')
const EternalStorageProxy = artifacts.require('./upgradeability/EternalStorageProxy.sol')
const {toBN, toWei} = web3.utils

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

const {
  CONSENSUS_ADDRESS,
  INITIAL_VALIDATOR_ADDRESS,
  MIN_STAKE_ETH
} = process.env

module.exports = function(deployer, network, accounts) {
  if (network !== 'test') {
    let initialValidatorAddress = INITIAL_VALIDATOR_ADDRESS || ZERO_ADDRESS
    let minStake = toWei(toBN(MIN_STAKE_ETH || 0), 'ether')
    let owner = accounts[0]

    let consensusImpl, proxy, consenus

    deployer.then(async function() {
      consensusImpl = await Consensus.new()

      proxy = await EternalStorageProxy.new()

      await proxy.methods['upgradeTo(uint256,address)']('1', consensusImpl.address)

      consensus = await Consensus.at(proxy.address)

      await consensus.initialize(minStake, initialValidatorAddress, owner)

      console.log(`Consensus Implementation ........................ ${consensusImpl.address}`)
      console.log(`Consensus Proxy          ........................ ${consensus.address}`)
    }).catch(function(error) {
      console.error(error)
    })
  }
}
