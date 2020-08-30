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

exports.ZERO = toBN(0)
exports.ONE = toBN(1)
exports.TWO = toBN(2)
exports.THREE = toBN(3)
exports.FOUR = toBN(4)

exports.advanceTime = (seconds) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [seconds],
      id: new Date().getTime()
    }, (err, result) => {
      if (err) { return reject(err) }
      return resolve(result)
    })
  })
}
exports.advanceBlocks = (n) => {
  return new Promise((resolve, reject) => {
    const tasks = []
    for (let i = 0; i < n; i++) {
      tasks.push(new Promise((resolve, reject) => {
        web3.currentProvider.send({
          jsonrpc: '2.0',
          method: 'evm_mine',
          id: new Date().getTime()
        }, async (err, result) => {
          if (err) { return reject(err) }
          const newBlock = await web3.eth.getBlock('latest')
          const newBlockNumber = newBlock.number
          return resolve(newBlockNumber)
        })
      }))
    }
    return tasks.reduce((promiseChain, currentTask) => {
      return promiseChain.then(chainResults =>
        currentTask.then(currentResult =>
          [ ...chainResults, currentResult ]
        )
      )
    }, Promise.resolve([])).then(results => {
      resolve(results[results.length - 1])
    })
  })
}