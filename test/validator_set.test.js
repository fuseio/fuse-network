const Consensus = artifacts.require('ConsensusMock.sol')
const {ERROR_MSG, ZERO_AMOUNT, ZERO_ADDRESS} = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const MIN_STAKE_AMOUNT = 10000
const MULTIPLY_AMOUNT = 3
const MIN_STAKE = toWei(toBN(MIN_STAKE_AMOUNT), 'ether')
const ONE_ETHER = toWei(toBN(1), 'ether')
const LESS_THAN_MIN_STAKE = toWei(toBN(MIN_STAKE_AMOUNT - 1), 'ether')
const MORE_THAN_MIN_STAKE = toWei(toBN(MIN_STAKE_AMOUNT + 1), 'ether')
const MULTIPLE_MIN_STAKE = toWei(toBN(MIN_STAKE_AMOUNT * MULTIPLY_AMOUNT), 'ether')
const SYSTEM_ADDRESS = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE'

contract('Consensus', async (accounts) => {
  let consensus
  let owner = accounts[0]
  let nonOwner = accounts[1]
  let initialValidator = accounts[0]
  let firstCandidate = accounts[1]
  let secondCandidate = accounts[2]

  describe('initialize', async () => {
    it('default values', async () => {
      consensus = await Consensus.new(MIN_STAKE, initialValidator)
      toChecksumAddress(SYSTEM_ADDRESS).should.be.equal(toChecksumAddress(await consensus.SYSTEM_ADDRESS()))
      false.should.be.equal(await consensus.finalized())
      MIN_STAKE.should.be.bignumber.equal(await consensus.minStake())
      owner.should.equal(await consensus.owner())
      let validators = await consensus.getValidators()
      validators.length.should.be.equal(1)
      validators[0].should.be.equal(initialValidator)
      let pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(0)
    })
    it('initial validator address not defined', async () => {
      consensus = await Consensus.new(MIN_STAKE, ZERO_ADDRESS)
      toChecksumAddress(SYSTEM_ADDRESS).should.be.equal(toChecksumAddress(await consensus.SYSTEM_ADDRESS()))
      false.should.be.equal(await consensus.finalized())
      MIN_STAKE.should.be.bignumber.equal(await consensus.minStake())
      owner.should.equal(await consensus.owner())
      let validators = await consensus.getValidators()
      validators.length.should.be.equal(1)
      validators[0].should.be.equal(owner)
      let pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(0)
    })
    it('initial validator address defined', async () => {
      consensus = await Consensus.new(MIN_STAKE, initialValidator)
      toChecksumAddress(SYSTEM_ADDRESS).should.be.equal(toChecksumAddress(await consensus.SYSTEM_ADDRESS()))
      false.should.be.equal(await consensus.finalized())
      MIN_STAKE.should.be.bignumber.equal(await consensus.minStake())
      owner.should.equal(await consensus.owner())
      let validators = await consensus.getValidators()
      validators.length.should.be.equal(1)
      validators[0].should.be.equal(initialValidator)
      let pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(0)
    })
    it('only owner can set minStake', async () => {
      consensus = await Consensus.new(MIN_STAKE, initialValidator)
      await consensus.setMinStake(LESS_THAN_MIN_STAKE, {from: nonOwner}).should.be.rejectedWith(ERROR_MSG)
      MIN_STAKE.should.be.bignumber.equal(await consensus.minStake())
      await consensus.setMinStake(LESS_THAN_MIN_STAKE, {from: owner})
      LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.minStake())
    })
  })
  describe('finalizeChange', async () => {
    beforeEach(async () => {
      consensus = await Consensus.new(MIN_STAKE, initialValidator)
    })
    it('should only be called by SYSTEM_ADDRESS', async () => {
      await consensus.finalizeChange().should.be.rejectedWith(ERROR_MSG)
      await consensus.setSystemAddress(accounts[0], {from: owner})
      await consensus.finalizeChange().should.be.fulfilled
    })
    it('should set finalized to true', async () => {
      false.should.be.equal(await consensus.finalized())
      await consensus.setSystemAddress(accounts[0])
      await consensus.finalizeChange().should.be.fulfilled
      true.should.be.equal(await consensus.finalized())
    })
  })
  describe('stake using payable', async () => {
    beforeEach(async () => {
      consensus = await Consensus.new(MIN_STAKE, initialValidator)
    })
    describe('basic', async () => {
      it('should no allow zero stake', async () => {
        await consensus.send(0, {from: firstCandidate}).should.be.rejectedWith(ERROR_MSG)
      })
      it('less than minimum stake', async () => {
        let {logs} = await consensus.sendTransaction({from: firstCandidate, value: LESS_THAN_MIN_STAKE})
        // contract balance should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // sender stake amount should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        // pending validators should not be updated
        let pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(0)
        // InitiateChange should not be emitted
        logs.length.should.be.equal(0)
      })
      it('more than minimum stake', async () => {
        let {logs} = await consensus.sendTransaction({from: firstCandidate, value: MORE_THAN_MIN_STAKE})
        // contract balance should be updated
        MORE_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // sender stake amount should be updated
        MORE_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        // validators state should be updated
        let state = await consensus.getValidatorState(firstCandidate)
        state[0].should.be.equal(true)
        state[1].should.be.equal(false)
        state[2].length.should.be.equal(1)
        state[2][0].should.be.bignumber.equal(toBN(0))
        // pending validators should be updated
        let pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
        // finalized should be updated to false
        false.should.be.equal(await consensus.finalized())
        // should emit InitiateChange with blockhash and pendingValidators
        logs.length.should.be.equal(1)
        logs[0].event.should.be.equal('InitiateChange')
        logs[0].args['newSet'].should.deep.equal(pendingValidators)
      })
    })
    describe('advanced', async () => {
      it('more than minimum stake amount, in more than one transaction', async () => {
        // 1st stake
        let {logs} = await consensus.sendTransaction({from: firstCandidate, value: LESS_THAN_MIN_STAKE})
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        let pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(0)
        logs.length.should.be.equal(0)

        // 2nd stake
        let tx = await consensus.sendTransaction({from: firstCandidate, value: ONE_ETHER})
        logs = tx.logs
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        let state = await consensus.getValidatorState(firstCandidate)
        state[0].should.be.equal(true)
        state[1].should.be.equal(false)
        state[2].length.should.be.equal(1)
        state[2][0].should.be.bignumber.equal(toBN(0))
        pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
        false.should.be.equal(await consensus.finalized())
        logs.length.should.be.equal(1)
        logs[0].event.should.be.equal('InitiateChange')
        logs[0].args['newSet'].should.deep.equal(pendingValidators)
      })
      it('more than one validator', async () => {
        // add 1st validator
        let tx1 = await consensus.sendTransaction({from: firstCandidate, value: MORE_THAN_MIN_STAKE})
        let pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(1)
        tx1.logs.length.should.be.equal(1)
        tx1.logs[0].event.should.be.equal('InitiateChange')
        tx1.logs[0].args['newSet'].should.deep.equal(pendingValidators)
        // add 2nd validator
        let tx2 = await consensus.sendTransaction({from: secondCandidate, value: MORE_THAN_MIN_STAKE})
        pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(2)
        tx2.logs.length.should.be.equal(1)
        tx2.logs[0].event.should.be.equal('InitiateChange')
        tx2.logs[0].args['newSet'].should.deep.equal(pendingValidators)
        // finalize change
        await consensus.setSystemAddress(accounts[0])
        let {logs} = await consensus.finalizeChange().should.be.fulfilled
        // currentValidators should be updated
        let currentValidatorsLength = await consensus.currentValidatorsLength()
        currentValidatorsLength.should.be.bignumber.equal(toBN(2))
        let currentValidators = await consensus.getValidators()
        currentValidators.length.should.be.equal(2)
        currentValidators.should.deep.equal(pendingValidators)
        logs[0].event.should.be.equal('ChangeFinalized')
        logs[0].args['newSet'].should.deep.equal(currentValidators)
      })
      it('multiple times according to staked amount', async () => {
        let expectedValidators = []
        for (let i = 0; i < MULTIPLY_AMOUNT; i++) {
          expectedValidators.push(firstCandidate)
        }
        let {logs} = await consensus.sendTransaction({from: firstCandidate, value: MULTIPLE_MIN_STAKE})
        // contract balance should be updated
        MULTIPLE_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // sender stake amount should be updated
        MULTIPLE_MIN_STAKE.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        // validators state should be updated
        let state = await consensus.getValidatorState(firstCandidate)
        state[0].should.be.equal(true)
        state[1].should.be.equal(false)
        state[2].length.should.be.equal(MULTIPLY_AMOUNT)
        state[2][0].should.be.bignumber.equal(toBN(0))
        state[2][1].should.be.bignumber.equal(toBN(1))
        state[2][2].should.be.bignumber.equal(toBN(2))
        // pending validators should be updattoBN(ed)
        let pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(MULTIPLY_AMOUNT)
        pendingValidators.should.deep.equal(expectedValidators)
        // finalized should be updated to false
        false.should.be.equal(await consensus.finalized())
        // should emit InitiateChange with blockhash and pendingValidators
        logs.length.should.be.equal(1)
        logs[0].event.should.be.equal('InitiateChange')
        logs[0].args['newSet'].should.deep.equal(pendingValidators)
      })
      it('multiple times according to staked amount, in more than one transaction', async () => {
        // 1st stake
        let {logs} = await consensus.sendTransaction({from: firstCandidate, value: LESS_THAN_MIN_STAKE})
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        let pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(0)
        logs.length.should.be.equal(0)

        // 2nd stake - added once
        let expectedValidators = [firstCandidate]
        let tx1 = await consensus.sendTransaction({from: firstCandidate, value: ONE_ETHER})
        logs = tx1.logs
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        let state = await consensus.getValidatorState(firstCandidate)
        state[0].should.be.equal(true)
        state[1].should.be.equal(false)
        state[2].length.should.be.equal(1)
        state[2][0].should.be.bignumber.equal(toBN(0))
        pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
        false.should.be.equal(await consensus.finalized())
        logs.length.should.be.equal(1)
        logs[0].event.should.be.equal('InitiateChange')
        logs[0].args['newSet'].should.deep.equal(pendingValidators)

        // 3rd stake - added MULTIPLY_AMOUNT more times
        for (let i = 0; i < MULTIPLY_AMOUNT; i++) {
          expectedValidators.push(firstCandidate)
        }
        let tx2 = await consensus.sendTransaction({from: firstCandidate, value: MULTIPLE_MIN_STAKE})
        logs = tx2.logs
        let amount = toWei(toBN(MIN_STAKE_AMOUNT * (1 + MULTIPLY_AMOUNT)), 'ether')
        amount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        amount.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
        state = await consensus.getValidatorState(firstCandidate)
        state[0].should.be.equal(true)
        state[1].should.be.equal(false)
        state[2].length.should.be.equal(expectedValidators.length)
        state[2][0].should.be.bignumber.equal(toBN(0))
        state[2][1].should.be.bignumber.equal(toBN(1))
        state[2][2].should.be.bignumber.equal(toBN(2))
        state[2][3].should.be.bignumber.equal(toBN(3))
        pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(1 + MULTIPLY_AMOUNT)
        pendingValidators.should.deep.equal(expectedValidators)
        false.should.be.equal(await consensus.finalized())
        logs.length.should.be.equal(1)
        logs[0].event.should.be.equal('InitiateChange')
        logs[0].args['newSet'].should.deep.equal(pendingValidators)
      })
      it('multiple validators, multiple times', async () => {
        let expectedValidators = []
        // add 1st validator
        expectedValidators.push(firstCandidate)
        let tx1 = await consensus.sendTransaction({from: firstCandidate, value: MORE_THAN_MIN_STAKE})
        let pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        tx1.logs.length.should.be.equal(1)
        tx1.logs[0].event.should.be.equal('InitiateChange')
        tx1.logs[0].args['newSet'].should.deep.equal(pendingValidators)
        // add 2nd validator
        expectedValidators.push(secondCandidate)
        let tx2 = await consensus.sendTransaction({from: secondCandidate, value: MORE_THAN_MIN_STAKE})
        pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        tx2.logs.length.should.be.equal(1)
        tx2.logs[0].event.should.be.equal('InitiateChange')
        tx2.logs[0].args['newSet'].should.deep.equal(pendingValidators)
        // add 1st validator MULTIPLY_AMOUNT more times
        for (let i = 0; i < MULTIPLY_AMOUNT; i++) {
          expectedValidators.push(firstCandidate)
        }
        let tx3 = await consensus.sendTransaction({from: firstCandidate, value: MULTIPLE_MIN_STAKE})
        pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        tx3.logs.length.should.be.equal(1)
        tx3.logs[0].event.should.be.equal('InitiateChange')
        tx3.logs[0].args['newSet'].should.deep.equal(pendingValidators)
        // add 2nd validator one more time
        expectedValidators.push(secondCandidate)
        let tx4 = await consensus.sendTransaction({from: secondCandidate, value: MORE_THAN_MIN_STAKE})
        pendingValidators = await consensus.getPendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        tx4.logs.length.should.be.equal(1)
        tx4.logs[0].event.should.be.equal('InitiateChange')
        tx4.logs[0].args['newSet'].should.deep.equal(pendingValidators)
        // finalize change
        await consensus.setSystemAddress(accounts[0])
        let {logs} = await consensus.finalizeChange().should.be.fulfilled
        // currentValidators should be updated
        let currentValidatorsLength = await consensus.currentValidatorsLength()
        currentValidatorsLength.should.be.bignumber.equal(toBN(expectedValidators.length))
        let currentValidators = await consensus.getValidators()
        currentValidators.length.should.be.equal(expectedValidators.length)
        currentValidators.should.deep.equal(pendingValidators)
        logs[0].event.should.be.equal('ChangeFinalized')
        logs[0].args['newSet'].should.deep.equal(currentValidators)
      })
    })
  })
  describe('withdraw', async () => {
    beforeEach(async () => {
      consensus = await Consensus.new(MIN_STAKE, initialValidator)
    })
    it('cannot withdraw zero', async () => {
      await consensus.withdraw(ZERO_AMOUNT).should.be.rejectedWith(ERROR_MSG)
    })
    it('cannot withdraw more than staked amount', async () => {
      await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE})
      await consensus.withdraw(MORE_THAN_MIN_STAKE).should.be.rejectedWith(ERROR_MSG)
    })
    it('can withdraw all staked amount and update validators', async () => {
      // stake
      await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE})
      // withdraw
      await consensus.withdraw(MIN_STAKE, {from: firstCandidate})
      ZERO_AMOUNT.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      ZERO_AMOUNT.should.be.bignumber.equal(await consensus.getStakeAmount(firstCandidate))
      // pendingValidators should be updated
      let pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(0)
      // finalize change
      await consensus.setSystemAddress(accounts[0])
      let {logs} = await consensus.finalizeChange().should.be.fulfilled
      // currentValidators should be updated
      let currentValidatorsLength = await consensus.currentValidatorsLength()
      currentValidatorsLength.should.be.bignumber.equal(toBN(0))
      let currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.equal(0)
      logs[0].event.should.be.equal('ChangeFinalized')
      logs[0].args['newSet'].should.deep.equal(currentValidators)
    })
    it('can withdraw less than staked amount and update validators', async () => {
      // stake
      await consensus.sendTransaction({from: firstCandidate, value: MULTIPLE_MIN_STAKE})
      // withdraw
      await consensus.withdraw(MIN_STAKE, {from: firstCandidate})
      let expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT * (MULTIPLY_AMOUNT - 1)), 'ether')
      let expectedValidators = []
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      for (let i = 0; i < MULTIPLY_AMOUNT - 1; i++) {
        expectedValidators.push(firstCandidate)
      }
      // pendingValidators should be updated
      let pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(MULTIPLY_AMOUNT - 1)
      pendingValidators.should.deep.equal(expectedValidators)
      // finalize change
      await consensus.setSystemAddress(accounts[0])
      let {logs} = await consensus.finalizeChange().should.be.fulfilled
      // currentValidators should be updated
      let currentValidatorsLength = await consensus.currentValidatorsLength()
      currentValidatorsLength.should.be.bignumber.equal(toBN(MULTIPLY_AMOUNT - 1))
      let currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.equal(MULTIPLY_AMOUNT - 1)
      currentValidators.should.deep.equal(expectedValidators)
      logs[0].event.should.be.equal('ChangeFinalized')
      logs[0].args['newSet'].should.deep.equal(currentValidators)
    })
    it('can withdraw multiple times and update validators accordingly', async () => {
      // stake
      await consensus.sendTransaction({from: firstCandidate, value: MULTIPLE_MIN_STAKE})
      // withdraw 1st time
      await consensus.withdraw(MIN_STAKE, {from: firstCandidate})
      let expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT * (MULTIPLY_AMOUNT - 1)), 'ether')
      let expectedValidators = []
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      for (let i = 0; i < MULTIPLY_AMOUNT - 1; i++) {
        expectedValidators.push(firstCandidate)
      }
      let pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(MULTIPLY_AMOUNT - 1)
      pendingValidators.should.deep.equal(expectedValidators)
      await consensus.setSystemAddress(accounts[0])
      let tx1 = await consensus.finalizeChange().should.be.fulfilled
      let currentValidatorsLength = await consensus.currentValidatorsLength()
      currentValidatorsLength.should.be.bignumber.equal(toBN(MULTIPLY_AMOUNT - 1))
      let currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.equal(MULTIPLY_AMOUNT - 1)
      currentValidators.should.deep.equal(expectedValidators)
      tx1.logs[0].event.should.be.equal('ChangeFinalized')
      tx1.logs[0].args['newSet'].should.deep.equal(currentValidators)
      // withdraw 2nd time
      await consensus.withdraw(MIN_STAKE, {from: firstCandidate})
      expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT * (MULTIPLY_AMOUNT - 2)), 'ether')
      expectedValidators = []
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      for (let i = 0; i < MULTIPLY_AMOUNT - 2; i++) {
        expectedValidators.push(firstCandidate)
      }
      pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(MULTIPLY_AMOUNT - 2)
      pendingValidators.should.deep.equal(expectedValidators)
      await consensus.setSystemAddress(accounts[0])
      let tx2 = await consensus.finalizeChange().should.be.fulfilled
      currentValidatorsLength = await consensus.currentValidatorsLength()
      currentValidatorsLength.should.be.bignumber.equal(toBN(MULTIPLY_AMOUNT - 2))
      currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.equal(MULTIPLY_AMOUNT - 2)
      currentValidators.should.deep.equal(expectedValidators)
      tx2.logs[0].event.should.be.equal('ChangeFinalized')
      tx2.logs[0].args['newSet'].should.deep.equal(currentValidators)
      // withdraw 3rd time
      await consensus.withdraw(MIN_STAKE, {from: firstCandidate})
      expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT * (MULTIPLY_AMOUNT - 3)), 'ether')
      expectedValidators = []
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
      for (let i = 0; i < MULTIPLY_AMOUNT - 3; i++) {
        expectedValidators.push(firstCandidate)
      }
      pendingValidators = await consensus.getPendingValidators()
      pendingValidators.length.should.be.equal(MULTIPLY_AMOUNT - 3)
      pendingValidators.should.deep.equal(expectedValidators)
      await consensus.setSystemAddress(accounts[0])
      let tx3 = await consensus.finalizeChange().should.be.fulfilled
      currentValidatorsLength = await consensus.currentValidatorsLength()
      currentValidatorsLength.should.be.bignumber.equal(toBN(MULTIPLY_AMOUNT - 3))
      currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.equal(MULTIPLY_AMOUNT - 3)
      currentValidators.should.deep.equal(expectedValidators)
      tx3.logs[0].event.should.be.equal('ChangeFinalized')
      tx3.logs[0].args['newSet'].should.deep.equal(currentValidators)
    })
  })
})
