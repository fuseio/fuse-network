const {BN, toBN, toWei} = web3.utils

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should()

exports.SYSTEM_ADDRESS = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE'
exports.ZERO_AMOUNT = toWei(toBN(0), 'ether')
exports.ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
exports.ERROR_MSG = 'VM Exception while processing transaction: revert'
exports.ERROR_MSG_OPCODE = 'VM Exception while processing transaction: invalid opcode'
exports.INVALID_ARGUMENTS = 'Invalid number of arguments to Solidity function'
exports.RANDOM_ADDRESS = '0xc0ffee254729296a45a3885639AC7E10F9d54979'
exports.THRESHOLD_TYPES = {
  INVALID: 0,
  VOTERS: 1,
  BLOCK_REWARD: 2,
  MIN_STAKE: 3
}
exports.CONTRACT_TYPES = {
  INVALID: 0,
  CONSENSUS: 1,
  BLOCK_REWARD: 2,
  BALLOTS_STORAGE: 3,
  PROXY_STORAGE: 4,
  VOTING_TO_CHANGE_BLOCK_REWARD: 5,
  VOTING_TO_CHANGE_MIN_STAKE: 6,
  VOTING_TO_CHANGE_MIN_THRESHOLD: 7,
  VOTING_TO_CHANGE_PROXY: 8
}
