const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BlockReward = artifacts.require('BlockReward.sol')
const Voting = artifacts.require('Voting.sol')
const {ERROR_MSG, ZERO_AMOUNT, SYSTEM_ADDRESS, ZERO_ADDRESS, RANDOM_ADDRESS, advanceBlocks} = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const MAX_VALIDATORS = 100
const MIN_STAKE_AMOUNT = 10000
const MULTIPLY_AMOUNT = 3
const MIN_STAKE = toWei(toBN(MIN_STAKE_AMOUNT), 'ether')
const ONE_ETHER = toWei(toBN(1), 'ether')
const LESS_THAN_MIN_STAKE = toWei(toBN(MIN_STAKE_AMOUNT - 1), 'ether')
const MORE_THAN_MIN_STAKE = toWei(toBN(MIN_STAKE_AMOUNT + 1), 'ether')
const CYCLE_DURATION_BLOCKS = 120
const SNAPSHOTS_PER_CYCLE = 10

contract('Consensus', async (accounts) => {
  let consensusImpl, proxy, consensus, blockReward, blockRewardAmount, decimals
  let owner = accounts[0]
  let nonOwner = accounts[1]
  let initialValidator = accounts[0]
  let firstCandidate = accounts[1]
  let secondCandidate = accounts[2]
  let thirdCandidate = accounts[3]
  let fourthCandidate = accounts[4]
  let firstDelegator = accounts[5]
  let secondDelegator = accounts[6]

  beforeEach(async () => {
    // Consensus
    consensusImpl = await Consensus.new()
    proxy = await EternalStorageProxy.new(ZERO_ADDRESS, consensusImpl.address)
    consensus = await Consensus.at(proxy.address)

    // ProxyStorage
    proxyStorageImpl = await ProxyStorage.new()
    proxy = await EternalStorageProxy.new(ZERO_ADDRESS, proxyStorageImpl.address)
    proxyStorage = await ProxyStorage.at(proxy.address)
    await proxyStorage.initialize(consensus.address)

    // BlockReward
    let blockRewardImpl = await BlockReward.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
    blockReward = await BlockReward.at(proxy.address)
    await blockReward.initialize(toWei(toBN(300000000000000000 || 0), 'gwei'))
    blockRewardAmount = await blockReward.getBlockRewardAmount()

    // Voting
    let votingImpl = await Voting.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, votingImpl.address)
    let voting = await Voting.at(proxy.address)

    // Initialize ProxyStorage
    await proxyStorage.initializeAddresses(
      blockReward.address,
      voting.address
    )
  })

  describe('initialize', async () => {
    it('default values', async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
      owner.should.equal(await proxy.getOwner())
      toChecksumAddress(SYSTEM_ADDRESS).should.be.equal(toChecksumAddress(await consensus.getSystemAddress()))
      true.should.be.equal(await consensus.isFinalized())
      MIN_STAKE.should.be.bignumber.equal(await consensus.getMinStake())
      toBN(MAX_VALIDATORS).should.be.bignumber.equal(await consensus.getMaxValidators())
      toBN(CYCLE_DURATION_BLOCKS).should.be.bignumber.equal(await consensus.getCycleDurationBlocks())
      toBN(SNAPSHOTS_PER_CYCLE).should.be.bignumber.equal(await consensus.getSnapshotsPerCycle())
      toBN(CYCLE_DURATION_BLOCKS / SNAPSHOTS_PER_CYCLE).should.be.bignumber.equal(await consensus.getBlocksToSnapshot())
      false.should.be.equal(await consensus.hasCycleEnded())
      toBN(0).should.be.bignumber.equal(await consensus.getLastSnapshotTakenAtBlock())
      toBN(0).should.be.bignumber.equal(await consensus.getNextSnapshotId())
      let validators = await consensus.getValidators()
      validators.length.should.be.equal(1)
      validators[0].should.be.equal(initialValidator)
      let pendingValidators = await consensus.pendingValidators()
      pendingValidators.length.should.be.equal(0)
    })
    it('initial validator address not defined - owner should be initial validator', async () => {
      await consensus.initialize(ZERO_ADDRESS)
      await consensus.setProxyStorage(proxyStorage.address)
      let validators = await consensus.getValidators()
      validators.length.should.be.equal(1)
      validators[0].should.be.equal(owner)
    })
    it('initial validator address defined', async () => {
      await consensus.initialize(initialValidator)
      let validators = await consensus.getValidators()
      validators.length.should.be.equal(1)
      validators[0].should.be.equal(initialValidator)
    })
  })

  describe('setProxyStorage', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
    })
    it('setProxyStorage should fail if no address', async () => {
      await consensus.setProxyStorage(ZERO_ADDRESS).should.be.rejectedWith(ERROR_MSG)
    })
    it('setProxyStorage should fail if not called by owner', async () => {
      await consensus.setProxyStorage(proxyStorage.address, {from: nonOwner}).should.be.rejectedWith(ERROR_MSG)
      // success
      await consensus.setProxyStorage(proxyStorage.address).should.be.fulfilled
      proxyStorage.address.should.be.equal(await consensus.getProxyStorage())
      // should not be able to set again if already set
      await consensus.setProxyStorage(RANDOM_ADDRESS).should.be.rejectedWith(ERROR_MSG)
    })
    it('setProxyStorage successfully', async () => {
      await consensus.setProxyStorage(proxyStorage.address).should.be.fulfilled
      proxyStorage.address.should.be.equal(await consensus.getProxyStorage())
    })
    it('setProxyStorage should not be able to set again if already set', async () => {
      await consensus.setProxyStorage(proxyStorage.address).should.be.fulfilled
      await consensus.setProxyStorage(RANDOM_ADDRESS).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('emitInitiateChange', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
      await consensus.setFinalizedMock(false)
    })
    it('should fail if not called by validator', async () => {
      await consensus.emitInitiateChange({from: nonOwner}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if newValidatorSet is empty', async () => {
      await consensus.setShouldEmitInitiateChangeMock(true)
      await consensus.emitInitiateChange({from: initialValidator}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if `shouldEmitInitiateChange` is false', async () => {
      let mockSet = [firstCandidate, secondCandidate]
      await consensus.setNewValidatorSetMock(mockSet)
      await consensus.emitInitiateChange({from: initialValidator}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should be successful and emit event', async () => {
      await consensus.setShouldEmitInitiateChangeMock(true)
      let mockSet = [firstCandidate, secondCandidate]
      await consensus.setNewValidatorSetMock(mockSet)
      let {logs} = await consensus.emitInitiateChange({from: initialValidator}).should.be.fulfilled
      false.should.be.equal(await consensus.shouldEmitInitiateChange())
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('InitiateChange')
      logs[0].args['newSet'].should.deep.equal(mockSet)
    })
  })

  describe('finalizeChange', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
      await consensus.setFinalizedMock(false)
    })
    it('should only be called by SYSTEM_ADDRESS', async () => {
      await consensus.finalizeChange().should.be.rejectedWith(ERROR_MSG)
      await consensus.setSystemAddressMock(accounts[0], {from: owner})
      await consensus.finalizeChange().should.be.fulfilled
    })
    it('should set finalized to true', async () => {
      false.should.be.equal(await consensus.isFinalized())
      await consensus.setSystemAddressMock(accounts[0])
      await consensus.finalizeChange().should.be.fulfilled
      true.should.be.equal(await consensus.isFinalized())
    })
    it('should not update current validators set if new set is empty', async () => {
      let initialValidators = await consensus.getValidators()
      let mockSet = []
      await consensus.setNewValidatorSetMock(mockSet)
      await consensus.setSystemAddressMock(accounts[0])
      let {logs} = await consensus.finalizeChange().should.be.fulfilled
      let currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.equal(1)
      currentValidators.should.deep.equal(initialValidators)
      logs.length.should.be.equal(0)
    })
    it('should update current validators set', async () => {
      let mockSet = [firstCandidate, secondCandidate]
      await consensus.setNewValidatorSetMock(mockSet)
      await consensus.setSystemAddressMock(accounts[0])
      let {logs} = await consensus.finalizeChange().should.be.fulfilled
      let currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.equal(2)
      currentValidators.should.deep.equal(mockSet)
      logs[0].event.should.be.equal('ChangeFinalized')
      logs[0].args['newSet'].should.deep.equal(mockSet)
    })
  })

  describe('stake (fallback function)', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
    })
    describe('basic', async () => {
      it('should not allow zero stake', async () => {
        await consensus.send(0, {from: firstCandidate}).should.be.rejectedWith(ERROR_MSG)
      })
      it('less than minimum stake - should not be added to pending validators', async () => {
        await consensus.sendTransaction({from: firstCandidate, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        // contract balance should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // sender stake amount should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        // pending validators should not be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        // validator fee should not be set
        toBN(0).should.be.bignumber.equal(await consensus.validatorFee(firstCandidate))
      })
      it('minimum stake amount', async () => {
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
        // default validator fee should be set
        let defaultValidatorFee = await consensus.DEFAULT_VALIDATOR_FEE()
        defaultValidatorFee.should.be.bignumber.equal(await consensus.validatorFee(firstCandidate))
      })
      it('should not allow more than minimum stake', async () => {
        await consensus.sendTransaction({from: firstCandidate, value: MORE_THAN_MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
      })
    })
    describe('advanced', async () => {
      it('minimum stake amount, in more than one transaction', async () => {
        // 1st stake
        await consensus.sendTransaction({from: firstCandidate, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)

        // 2nd stake
        await consensus.sendTransaction({from: firstCandidate, value: ONE_ETHER}).should.be.fulfilled
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
      })
      it('more than one validator', async () => {
        // add 1st validator
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        // add 2nd validator
        await consensus.sendTransaction({from: secondCandidate, value: MIN_STAKE}).should.be.fulfilled
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(2)
      })
      it('multiple validators, multiple times', async () => {
        let expectedValidators = []
        // add 1st validator
        expectedValidators.push(firstCandidate)
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        // add 2nd validator
        expectedValidators.push(secondCandidate)
        await consensus.sendTransaction({from: secondCandidate, value: MIN_STAKE}).should.be.fulfilled
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        // try to add 1st validator one more time - should reject
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
        // try to add 2nd validator one more time - should reject
        await consensus.sendTransaction({from: secondCandidate, value: MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
      })
    })
  })

  describe('stake', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
    })
    describe('basic', async () => {
      it('should not allow zero stake', async () => {
        await consensus.stake({from: firstCandidate, value: 0}).should.be.rejectedWith(ERROR_MSG)
      })
      it('less than minimum stake - should not be added to pending validators', async () => {
        await consensus.stake({from: firstCandidate, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        // contract balance should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // sender stake amount should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        // pending validators should not be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
      })
      it('minimum stake amount', async () => {
        await consensus.stake({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
      })
      it('should not allow more than minimum stake', async () => {
        await consensus.stake({from: firstCandidate, value: MORE_THAN_MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
      })
    })
    describe('advanced', async () => {
      it('minimum stake amount, in more than one transaction', async () => {
        // 1st stake
        await consensus.stake({from: firstCandidate, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)

        // 2nd stake
        await consensus.stake({from: firstCandidate, value: ONE_ETHER}).should.be.fulfilled
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
      })
      it('more than one validator', async () => {
        // add 1st validator
        await consensus.stake({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        // add 2nd validator
        await consensus.stake({from: secondCandidate, value: MIN_STAKE}).should.be.fulfilled
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(2)
      })
      it('multiple times according to staked amount, in more than one transaction', async () => {
        // 1st stake
        await consensus.stake({from: firstCandidate, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)

        // 2nd stake - added once
        let expectedValidators = [firstCandidate]
        await consensus.stake({from: firstCandidate, value: ONE_ETHER}).should.be.fulfilled
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)

        // 3rd stake - should be rejected
        await consensus.stake({from: firstCandidate, value: MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
      })
      it('multiple validators, multiple times', async () => {
        let expectedValidators = []
        // add 1st validator
        expectedValidators.push(firstCandidate)
        await consensus.stake({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        // add 2nd validator
        expectedValidators.push(secondCandidate)
        await consensus.stake({from: secondCandidate, value: MIN_STAKE}).should.be.fulfilled
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(expectedValidators.length)
        pendingValidators.should.deep.equal(expectedValidators)
        // try to add 1st validator one more time - should reject
        await consensus.stake({from: firstCandidate, value: MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
        // try to add 2nd validator one more time - should reject
        await consensus.stake({from: secondCandidate, value: MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
      })
    })
  })

  describe('delegate', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
    })
    describe('basic', async () => {
      it('should not allow zero stake', async () => {
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: 0}).should.be.rejectedWith(ERROR_MSG)
      })
      it('should fail if no staker address', async () => {
        await consensus.delegate(ZERO_ADDRESS, {from: firstDelegator, value: MORE_THAN_MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
      })
      it('less than minimum stake - should not be added to pending validators', async () => {
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        // contract balance should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // sender stake amount should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        // delegated amount should be updated
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, firstCandidate))
        // pending validators should not be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        // delegators list should be updated
        let delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        let delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
      })
      it('minimum stake', async () => {
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE}).should.be.fulfilled
        // contract balance should be updated
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // sender stake amount should be updated
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        // delegated amount should be updated
        MIN_STAKE.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, firstCandidate))
        // pending validators should be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
        // delegators list should be updated
        let delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        let delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
      })
    })
    describe('advanced', async () => {
      it('minimum stake amount, in more than one transaction', async () => {
        // 1st stake
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, firstCandidate))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        let delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        let delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))

        // 2nd stake
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: ONE_ETHER}).should.be.fulfilled
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        MIN_STAKE.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, firstCandidate))
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
        delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
      })
      it('more than one validator', async () => {
        // add 1st validator
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE}).should.be.fulfilled
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        // delegators list should be updated
        let delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        let delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
        // add 2nd validator
        await consensus.delegate(secondCandidate, {from: firstDelegator, value: MIN_STAKE}).should.be.fulfilled
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(2)
        // delegators list should be updated
        delegators = await consensus.delegators(secondCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(secondCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(secondCandidate, 0))
      })
      it('multiple times according to staked amount, in more than one transaction', async () => {
        // 1st stake
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: LESS_THAN_MIN_STAKE}).should.be.fulfilled
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        LESS_THAN_MIN_STAKE.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, firstCandidate))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        let delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        let delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))

        // 2nd stake - added once
        let expectedValidators = [firstCandidate]
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: ONE_ETHER}).should.be.fulfilled
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        MIN_STAKE.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        MIN_STAKE.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, firstCandidate))
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators[0].should.be.equal(firstCandidate)
        delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))

        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE}).should.be.rejectedWith(ERROR_MSG)
        delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
      })
    })
  })

  describe('cycles and snapshots', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
    })
    it('hasCycleEnded', async () => {
      false.should.be.equal(await consensus.hasCycleEnded())
      let currentBlockNumber = await web3.eth.getBlockNumber()
      let currentCycleEndBlock = await consensus.getCurrentCycleEndBlock()
      let blocksToAdvance = currentCycleEndBlock.toNumber() - currentBlockNumber
      await advanceBlocks(blocksToAdvance - 1)
      true.should.be.equal(await consensus.hasCycleEnded())
    })
    it('shouldTakeSnapshot', async () => {
      let blocksToSnapshot = await consensus.getBlocksToSnapshot()
      let lastSnapshotTakenAtBlock = await consensus.getLastSnapshotTakenAtBlock()
      let currentBlockNumber = toBN(await web3.eth.getBlockNumber())
      let shouldTakeSnapshot = (currentBlockNumber.sub(lastSnapshotTakenAtBlock)).gte(blocksToSnapshot)
      shouldTakeSnapshot.should.be.equal(await consensus.shouldTakeSnapshot())
    })
    it('getRandom', async () => {
      let repeats = 25
      let randoms = []
      for (let i = 0; i < repeats; i++) {
        randoms.push((await consensus.getRandom(0, SNAPSHOTS_PER_CYCLE)).toNumber())
        await advanceBlocks(1)
      }
      randoms.length.should.be.equal(repeats)
      let distincts = [...new Set(randoms)]
      distincts.length.should.be.greaterThan(1)
      distincts.length.should.be.most(SNAPSHOTS_PER_CYCLE)
    })
    it('cycle function should only be called by BlockReward', async () => {
      await consensus.cycle().should.be.rejectedWith(ERROR_MSG)
      await proxyStorage.setBlockRewardMock(owner)
      await consensus.cycle().should.be.fulfilled
    })
    it('snapshot with less validators than MAX_VALIDATORS - entire set should be saved', async () => {
      let expectedValidators = []
      for (let i = 1; i <= MAX_VALIDATORS - 1; i++) {
        await consensus.sendTransaction({from: accounts[i-1], value: MIN_STAKE}).should.be.fulfilled
        expectedValidators.push(accounts[i-1])
      }
      pendingValidators = await consensus.pendingValidators()
      pendingValidators.length.should.be.equal(expectedValidators.length)
      pendingValidators.should.deep.equal(expectedValidators)
      let blocksToSnapshot = await consensus.getBlocksToSnapshot()
      let snapshotId = await consensus.getNextSnapshotId()
      await advanceBlocks(blocksToSnapshot)
      await proxyStorage.setBlockRewardMock(owner)
      await consensus.cycle().should.be.fulfilled
      let snapshot = await consensus.getSnapshotAddresses(snapshotId)
      snapshot.length.should.be.equal(expectedValidators.length)
      snapshot.forEach(address => {
        expectedValidators.splice(expectedValidators.indexOf(address), 1)
      })
      expectedValidators.length.should.be.equal(0)
    })
    it('snapshot with exactly MAX_VALIDATORS validators - entire set should be saved', async () => {
      let expectedValidators = []
      for (let i = 1; i <= MAX_VALIDATORS; i++) {
        await consensus.sendTransaction({from: accounts[i-1], value: MIN_STAKE}).should.be.fulfilled
        expectedValidators.push(accounts[i-1])
      }
      pendingValidators = await consensus.pendingValidators()
      pendingValidators.length.should.be.equal(expectedValidators.length)
      pendingValidators.should.deep.equal(expectedValidators)
      let blocksToSnapshot = await consensus.getBlocksToSnapshot()
      let snapshotId = await consensus.getNextSnapshotId()
      await advanceBlocks(blocksToSnapshot)
      await proxyStorage.setBlockRewardMock(owner)
      await consensus.cycle().should.be.fulfilled
      let snapshot = await consensus.getSnapshotAddresses(snapshotId)
      snapshot.length.should.be.equal(expectedValidators.length)
      snapshot.forEach(address => {
        expectedValidators.splice(expectedValidators.indexOf(address), 1)
      })
      expectedValidators.length.should.be.equal(0)
    })
    it('snapshot with more validators than MAX_VALIDATORS - random set should be saved', async () => {
      let expectedValidators = []
      for (let i = 1; i <= MAX_VALIDATORS + 1; i++) {
        await consensus.sendTransaction({from: accounts[i-1], value: MIN_STAKE}).should.be.fulfilled
        expectedValidators.push(accounts[i-1])
      }
      pendingValidators = await consensus.pendingValidators()
      pendingValidators.length.should.be.equal(expectedValidators.length)
      pendingValidators.should.deep.equal(expectedValidators)
      let blocksToSnapshot = await consensus.getBlocksToSnapshot()
      let snapshotId = await consensus.getNextSnapshotId()
      await advanceBlocks(blocksToSnapshot)
      await proxyStorage.setBlockRewardMock(owner)
      await consensus.cycle().should.be.fulfilled
      let snapshot = await consensus.getSnapshotAddresses(snapshotId)
      snapshot.length.should.be.equal(MAX_VALIDATORS)
      snapshot.forEach(address => {
        expectedValidators.splice(expectedValidators.indexOf(address), 1)
      })
      expectedValidators.length.should.be.equal(pendingValidators.length - MAX_VALIDATORS)
    })
  })

  describe('withdraw', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
    })
    describe('stakers', async () => {
      it('cannot withdraw zero', async () => {
        await consensus.methods['withdraw(uint256)'](ZERO_AMOUNT, {from: firstCandidate}).should.be.rejectedWith(ERROR_MSG)
      })
      it('cannot withdraw more than staked amount', async () => {
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE})
        await consensus.methods['withdraw(uint256)'](MORE_THAN_MIN_STAKE).should.be.rejectedWith(ERROR_MSG)
      })
      it('can withdraw all staked amount', async () => {
        // stake
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE})
        // stake
        await consensus.sendTransaction({from: secondCandidate, value: MIN_STAKE})
        // withdraw
        await consensus.methods['withdraw(uint256)'](MIN_STAKE, {from: firstCandidate})
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        ZERO_AMOUNT.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        // pendingValidators should be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators.should.deep.equal([secondCandidate])
      })
      it('can withdraw less than staked amount', async () => {
        // stake
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE})
        // withdraw
        await consensus.methods['withdraw(uint256)'](ONE_ETHER, {from: firstCandidate})
        let expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT - 1), 'ether')
        let expectedValidators = []
        expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // pendingValidators should be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
      })
      it('can withdraw multiple times', async () => {
        // stake
        await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE})
        // withdraw 1st time
        await consensus.methods['withdraw(uint256)'](ONE_ETHER, {from: firstCandidate})
        let expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT - 1), 'ether')
        let expectedValidators = []
        expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        // withdraw 2nd time
        await consensus.withdraw(ONE_ETHER, {from: firstCandidate})
        expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT - 2), 'ether')
        expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
      })
    })
    describe('delegators', async () => {
      it('cannot withdraw zero', async () => {
        await consensus.methods['withdraw(address,uint256)'](firstCandidate, ZERO_AMOUNT, {from: firstDelegator}).should.be.rejectedWith(ERROR_MSG)
      })
      it('cannot withdraw if no staker address defined', async () => {
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE}).should.be.fulfilled
        await consensus.methods['withdraw(address,uint256)'](ZERO_ADDRESS, MIN_STAKE, {from: firstDelegator}).should.be.rejectedWith(ERROR_MSG)
      })
      it('cannot withdraw more than staked amount', async () => {
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE})
        await consensus.methods['withdraw(address,uint256)'](firstCandidate, MORE_THAN_MIN_STAKE, {from: firstDelegator}).should.be.rejectedWith(ERROR_MSG)
      })
      it('can withdraw all staked amount', async () => {
        // stake
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE})
        // stake
        await consensus.delegate(secondCandidate, {from: firstDelegator, value: MIN_STAKE})
        // withdraw
        await consensus.methods['withdraw(address,uint256)'](firstCandidate, MIN_STAKE, {from: firstDelegator})
        MIN_STAKE.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        ZERO_AMOUNT.should.be.bignumber.equal(await consensus.stakeAmount(firstCandidate))
        ZERO_AMOUNT.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, firstCandidate))
        MIN_STAKE.should.be.bignumber.equal(await consensus.delegatedAmount(firstDelegator, secondCandidate))
        // pendingValidators should be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(1)
        pendingValidators.should.deep.equal([secondCandidate])
        // delegators list should be updated for firstCandidate
        let delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(0)
        let delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(0))
        // delegators list should be updated for secondCandidate
        delegators = await consensus.delegators(secondCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(secondCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(secondCandidate, 0))
      })
      it('can withdraw less than staked amount', async () => {
        // stake
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE})
        // withdraw
        await consensus.methods['withdraw(address,uint256)'](firstCandidate, ONE_ETHER, {from: firstDelegator})
        let expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT - 1), 'ether')
        let expectedValidators = []
        expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        // pendingValidators should be updated
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        // delegators list should be updated
        delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
      })
      it('can withdraw multiple times', async () => {
        // stake
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: MIN_STAKE})
        // withdraw 1st time
        await consensus.methods['withdraw(address,uint256)'](firstCandidate, ONE_ETHER, {from: firstDelegator})
        let expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT - 1), 'ether')
        let expectedValidators = [firstCandidate]
        expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        let pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        // delegators list should be updated
        delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
        // withdraw 2nd time
        await consensus.methods['withdraw(address,uint256)'](firstCandidate, ONE_ETHER, {from: firstDelegator})
        expectedAmount = toWei(toBN(MIN_STAKE_AMOUNT - 2), 'ether')
        expectedAmount.should.be.bignumber.equal(await web3.eth.getBalance(consensus.address))
        pendingValidators = await consensus.pendingValidators()
        pendingValidators.length.should.be.equal(0)
        // delegators list should be updated
        delegators = await consensus.delegators(firstCandidate)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        delegatorsLength = await consensus.delegatorsLength(firstCandidate)
        delegatorsLength.should.be.bignumber.equal(toBN(1))
        firstDelegator.should.be.equal(await consensus.delegatorsAtPosition(firstCandidate, 0))
      })
    })
  })

  describe('setValidatorFee', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
    })
    it('should only be called by validator', async () => {
      decimals = await consensus.DECIMALS()
      await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
      let defaultValidatorFee = await consensus.DEFAULT_VALIDATOR_FEE()
      defaultValidatorFee.should.be.bignumber.equal(await consensus.validatorFee(firstCandidate))
      let newValidatorFee = defaultValidatorFee.sub(toBN(0.01 * decimals))
      await consensus.setValidatorFee(newValidatorFee, {from: initialValidator}).should.be.fulfilled
      newValidatorFee.should.be.bignumber.equal(await consensus.validatorFee(initialValidator))
      await consensus.setValidatorFee(newValidatorFee, {from: secondCandidate}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should only be able to set a valid fee', async () => {
      decimals = await consensus.DECIMALS()
      let i;
      for (i = 0; i <= 100; i++) {
        await consensus.setValidatorFee(toBN(i/100 * decimals), {from: initialValidator}).should.be.fulfilled
      }
      await consensus.setValidatorFee(toBN(i/100 * decimals), {from: initialValidator}).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('getDelegatorsForRewardDistribution', async () => {
    beforeEach(async () => {
      await consensus.initialize(initialValidator)
      await consensus.setProxyStorage(proxyStorage.address)
    })
    it('validator without delegators', async () => {
      await consensus.sendTransaction({from: firstCandidate, value: MIN_STAKE}).should.be.fulfilled
      let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
      delegators.length.should.be.equal(0)
      rewards.length.should.be.equal(0)
    })
    describe('validator with one delegator', async () => {
      it('total delegated more than total staked - no fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.25), 'ether')
        let delegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.75), 'ether')
        let fee = toBN(0 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: delegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        rewards.length.should.be.equal(delegators.length)
        let expectedReward = blockRewardAmount.mul(delegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals)
        rewards[0].should.be.bignumber.equal(expectedReward)
      })
      it('total delegated less than total staked - no fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.75), 'ether')
        let delegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.25), 'ether')
        let fee = toBN(0 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: delegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        rewards.length.should.be.equal(delegators.length)
        let expectedReward = blockRewardAmount.mul(delegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals)
        rewards[0].should.be.bignumber.equal(expectedReward)
      })
      it('total delegated more than total staked - 100% fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.25), 'ether')
        let delegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.75), 'ether')
        let fee = toBN(1 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: delegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        rewards.length.should.be.equal(delegators.length)
        let expectedReward = blockRewardAmount.mul(delegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals)
        rewards[0].should.be.bignumber.equal(expectedReward)
      })
      it('total delegated less than total staked - 100% fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.75), 'ether')
        let delegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.25), 'ether')
        let fee = toBN(1 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: delegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        rewards.length.should.be.equal(delegators.length)
        let expectedReward = blockRewardAmount.mul(delegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals)
        rewards[0].should.be.bignumber.equal(expectedReward)
      })
      it('total delegated more than total staked - other fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.25), 'ether')
        let delegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.75), 'ether')
        let fee = toBN(0.225 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: delegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        rewards.length.should.be.equal(delegators.length)
        let expectedReward = blockRewardAmount.mul(delegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals)
        rewards[0].should.be.bignumber.equal(expectedReward)
      })
      it('total delegated less than total staked - other fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.75), 'ether')
        let delegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.25), 'ether')
        let fee = toBN(0.225 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: delegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(1)
        delegators[0].should.be.equal(firstDelegator)
        rewards.length.should.be.equal(delegators.length)
        let expectedReward = blockRewardAmount.mul(delegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals)
        rewards[0].should.be.bignumber.equal(expectedReward)
      })
    })
    describe('validator with multiple delegators', async () => {
      it('total delegated more than total staked - no fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.1), 'ether')
        let firstDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.2), 'ether')
        let secondDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.7), 'ether')
        let fee = toBN(0 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: firstDelegateAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: secondDelegator, value: secondDelegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(2)
        delegators[0].should.be.equal(firstDelegator)
        delegators[1].should.be.equal(secondDelegator)
        rewards.length.should.be.equal(delegators.length)
        rewards[0].should.be.bignumber.equal(blockRewardAmount.mul(firstDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
        rewards[1].should.be.bignumber.equal(blockRewardAmount.mul(secondDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
      })
      it('total delegated less than total staked - no fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.7), 'ether')
        let firstDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.2), 'ether')
        let secondDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.1), 'ether')
        let fee = toBN(0 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: firstDelegateAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: secondDelegator, value: secondDelegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(2)
        delegators[0].should.be.equal(firstDelegator)
        delegators[1].should.be.equal(secondDelegator)
        rewards.length.should.be.equal(delegators.length)
        rewards[0].should.be.bignumber.equal(blockRewardAmount.mul(firstDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
        rewards[1].should.be.bignumber.equal(blockRewardAmount.mul(secondDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
      })
      it('total delegated more than total staked - 100% fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.1), 'ether')
        let firstDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.2), 'ether')
        let secondDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.7), 'ether')
        let fee = toBN(1 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: firstDelegateAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: secondDelegator, value: secondDelegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(2)
        delegators[0].should.be.equal(firstDelegator)
        delegators[1].should.be.equal(secondDelegator)
        rewards.length.should.be.equal(delegators.length)
        rewards[0].should.be.bignumber.equal(blockRewardAmount.mul(firstDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
        rewards[1].should.be.bignumber.equal(blockRewardAmount.mul(secondDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
      })
      it('total delegated less than total staked - 100% fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.7), 'ether')
        let firstDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.2), 'ether')
        let secondDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.1), 'ether')
        let fee = toBN(1 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: firstDelegateAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: secondDelegator, value: secondDelegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(2)
        delegators[0].should.be.equal(firstDelegator)
        delegators[1].should.be.equal(secondDelegator)
        rewards.length.should.be.equal(delegators.length)
        rewards[0].should.be.bignumber.equal(blockRewardAmount.mul(firstDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
        rewards[1].should.be.bignumber.equal(blockRewardAmount.mul(secondDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
      })
      it('total delegated more than total staked - other fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.1), 'ether')
        let firstDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.2), 'ether')
        let secondDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.7), 'ether')
        let fee = toBN(0.15 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: firstDelegateAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: secondDelegator, value: secondDelegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(2)
        delegators[0].should.be.equal(firstDelegator)
        delegators[1].should.be.equal(secondDelegator)
        rewards.length.should.be.equal(delegators.length)
        rewards[0].should.be.bignumber.equal(blockRewardAmount.mul(firstDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
        rewards[1].should.be.bignumber.equal(blockRewardAmount.mul(secondDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
      })
      it('total delegated less than total staked - other fee', async () => {
        decimals = await consensus.DECIMALS()
        let stakeAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.7), 'ether')
        let firstDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.2), 'ether')
        let secondDelegateAmount = toWei(toBN(MIN_STAKE_AMOUNT * 0.1), 'ether')
        let fee = toBN(0.15 * decimals)
        await consensus.sendTransaction({from: firstCandidate, value: stakeAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: firstDelegator, value: firstDelegateAmount}).should.be.fulfilled
        await consensus.delegate(firstCandidate, {from: secondDelegator, value: secondDelegateAmount}).should.be.fulfilled
        await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
        let validatorFee = await consensus.validatorFee(firstCandidate)
        let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
        delegators.length.should.be.equal(2)
        delegators[0].should.be.equal(firstDelegator)
        delegators[1].should.be.equal(secondDelegator)
        rewards.length.should.be.equal(delegators.length)
        rewards[0].should.be.bignumber.equal(blockRewardAmount.mul(firstDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
        rewards[1].should.be.bignumber.equal(blockRewardAmount.mul(secondDelegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals))
      })
    })
    it('validator with many delegators', async () => {
      decimals = await consensus.DECIMALS()
      let delegatorsCount = accounts.length - 2
      let delegateAmountValue = parseInt(MIN_STAKE_AMOUNT * 0.99 / delegatorsCount)
      let delegateAmount = toWei(toBN(delegateAmountValue), 'ether')
      let stakeAmountValue = MIN_STAKE_AMOUNT - delegateAmountValue * delegatorsCount
      let stakeAmount = toWei(toBN(stakeAmountValue), 'ether')
      let fee = toBN(0.05 * decimals)
      let validator = accounts[1]
      await consensus.sendTransaction({from: validator, value: stakeAmount}).should.be.fulfilled
      for (let i = 2; i < accounts.length; i++) {
        await consensus.delegate(validator, {from: accounts[i], value: delegateAmount}).should.be.fulfilled
      }
      await consensus.setValidatorFeeMock(fee, {from: firstCandidate}).should.be.fulfilled
      let validatorFee = await consensus.validatorFee(firstCandidate)
      let { 0: delegators, 1: rewards } = await consensus.getDelegatorsForRewardDistribution(firstCandidate, blockRewardAmount)
      delegators.length.should.be.equal(delegatorsCount)
      rewards.length.should.be.equal(delegators.length)
      let expectedReward = blockRewardAmount.mul(delegateAmount).div(MIN_STAKE).mul(decimals.sub(validatorFee)).div(decimals)
      for (let i = 0; i < delegatorsCount; i++) {
        delegators[i].should.be.equal(accounts[i + 2])
        rewards[i].should.be.bignumber.equal(expectedReward)
      }
    })
  })

  describe('upgradeTo', async () => {
    let consensusOldImplementation, consensusNew
    let proxyStorageStub = accounts[3]
    beforeEach(async () => {
      consensus = await Consensus.new()
      consensusOldImplementation = consensus.address
      proxy = await EternalStorageProxy.new(proxyStorage.address, consensus.address)
      consensus = await Consensus.at(proxy.address)
      consensusNew = await Consensus.new()
    })
    it('should only be called by ProxyStorage', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(consensusNew.address, {from: owner}).should.be.rejectedWith(ERROR_MSG)
      let {logs} = await proxy.upgradeTo(consensusNew.address, {from: proxyStorageStub})
      logs[0].event.should.be.equal('Upgraded')
      await proxy.setProxyStorageMock(proxyStorage.address)
    })
    it('should change implementation address', async () => {
      consensusOldImplementation.should.be.equal(await proxy.getImplementation())
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(consensusNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      consensusNew.address.should.be.equal(await proxy.getImplementation())
    })
    it('should increment implementation version', async () => {
      let consensusOldVersion = await proxy.getVersion()
      let consensusNewVersion = consensusOldVersion.add(toBN(1))
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(consensusNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      consensusNewVersion.should.be.bignumber.equal(await proxy.getVersion())
    })
    it('should work after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(consensusNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      consensusNew = await Consensus.at(proxy.address)
      false.should.be.equal(await consensusNew.isInitialized())
      await consensusNew.initialize(initialValidator).should.be.fulfilled
      true.should.be.equal(await consensusNew.isInitialized())
    })
    it('should use same proxyStorage after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(consensusNew.address, {from: proxyStorageStub})
      consensusNew = await Consensus.at(proxy.address)
      proxyStorageStub.should.be.equal(await consensusNew.getProxyStorage())
    })
    it('should use same storage after upgrade', async () => {
      await consensus.setSystemAddressMock(RANDOM_ADDRESS, {from: owner})
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(consensusNew.address, {from: proxyStorageStub})
      consensusNew = await Consensus.at(proxy.address)
      RANDOM_ADDRESS.should.be.equal(await consensus.getSystemAddress())
    })
  })
})
