require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(web3.BigNumber))
  .should()

exports.ZERO_AMOUNT = web3.toWei(0, 'ether')
exports.ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
exports.ERROR_MSG = 'VM Exception while processing transaction: revert'
exports.ERROR_MSG_OPCODE = 'VM Exception while processing transaction: invalid opcode'
exports.INVALID_ARGUMENTS = 'Invalid number of arguments to Solidity function'
