const {BN, toBN, toWei} = web3.utils

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should()

exports.ZERO_AMOUNT = toWei(toBN(0), 'ether')
exports.ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
exports.ERROR_MSG = 'VM Exception while processing transaction: revert'
exports.ERROR_MSG_OPCODE = 'VM Exception while processing transaction: invalid opcode'
exports.INVALID_ARGUMENTS = 'Invalid number of arguments to Solidity function'
