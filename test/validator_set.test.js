const ValidatorSet = artifacts.require('ValidatorSet.sol')
const {ERROR_MSG} = require('./helpers')

const MIN_STAKE = web3.toWei(10000, 'ether')
const HALF_MIN_STAKE = web3.toWei(5000, 'ether')
const EXACTLY_MIN_STAKE = MIN_STAKE
const MORE_THAN_MIN_STAKE = web3.toWei(10001, 'ether')
const MAX_GAS = 4700000

contract('ValidatorSet', async (accounts) => {
  let validatorSet
  let owner = accounts[0]
  let nonOwner = accounts[1]
  let firstCandidate = accounts[1]
  let secondCandidate = accounts[2]

  beforeEach(async () => {
    validatorSet = await ValidatorSet.new(MIN_STAKE)
  })
  describe('initialize', async () => {
    it('should set initial values', async () => {
      MIN_STAKE.should.be.bignumber.equal(await validatorSet.minStake())
      owner.should.equal(await validatorSet.owner())
      let validators = await validatorSet.getValidators()
      validators.length.should.be.equal(0)
      let pendingValidators = await validatorSet.getPendingValidators()
      pendingValidators.length.should.be.equal(0)
    })
    it('only owner can set minStake', async () => {
      await validatorSet.setMinStake(HALF_MIN_STAKE, {from: nonOwner}).should.be.rejectedWith(ERROR_MSG)
      MIN_STAKE.should.be.bignumber.equal(await validatorSet.minStake())

      await validatorSet.setMinStake(HALF_MIN_STAKE, {from: owner})
      HALF_MIN_STAKE.should.be.bignumber.equal(await validatorSet.minStake())
    })
  })

  describe('stake using payable', async () => {
    describe('basic', async () => {
      it('zero', async () => {
        await validatorSet.send(0, {from: firstCandidate}).should.be.rejectedWith(ERROR_MSG)
      })
      it('less than minimum stake', async () => {
        await web3.eth.sendTransaction({from: firstCandidate, to: validatorSet.address, value: HALF_MIN_STAKE, gas: MAX_GAS})

        // contract balance should be updated
        HALF_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(validatorSet.address))

        // sender stake amount should be updated
        HALF_MIN_STAKE.should.be.bignumber.equal(await validatorSet.getStakeAmount(firstCandidate))

        // pending validators should not be updated
        let pendingValidators = await validatorSet.getPendingValidators()
        pendingValidators.length.should.be.equal(0)
      })
      it('more than minimum stake', async () => {
        await web3.eth.sendTransaction({from: firstCandidate, to: validatorSet.address, value: MORE_THAN_MIN_STAKE, gas: MAX_GAS})

        // contract balance should be updated
        MORE_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(validatorSet.address))

        // sender stake amount should be updated
        MORE_THAN_MIN_STAKE.should.be.bignumber.equal(await validatorSet.getStakeAmount(firstCandidate))

        // validators state should be updated
        let validatorState = await validatorSet.validatorsState(firstCandidate)
        validatorState[0].should.be.equal(true)          // isValidator
        validatorState[1].should.be.equal(false)         // isValidatorFinalized
        validatorState[2].should.be.bignumber.equal(0)   // index

        // pending validators should be updated
        let pendingValidators = await validatorSet.getPendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
      })
    })
    describe('advanced', async () => {
      // TODO accumulative amount up to minStake
      // TODO if stakeAmount > minStake should be added as validator X times (where X = stakeAmount/minStake)
    })
  })
})
