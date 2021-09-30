const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BlockReward = artifacts.require('BlockReward.sol')
const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const Voting = artifacts.require('VotingMock.sol')
const {ERROR_MSG, ZERO_ADDRESS, RANDOM_ADDRESS, advanceBlocks} = require('./helpers')
const {toBN, toWei} = web3.utils

const CYCLE_DURATION_BLOCKS = 120
const SNAPSHOTS_PER_CYCLE = 2
const MIN_BALLOT_DURATION_CYCLES = 2

const CONTRACT_TYPES = { INVALID: 0, CONSENSUS: 1, BLOCK_REWARD: 2, PROXY_STORAGE: 3, VOTING: 4 }
const QUORUM_STATES = { INVALID: 0, IN_PROGRESS: 1, ACCEPTED: 2, REJECTED: 3 }
const ACTION_CHOICES = { INVALID: 0, ACCEPT: 1, REJECT: 2 }

contract('Voting', async (accounts) => {
  let consensus, consensusImpl, proxy, proxyStorage, proxyStorageImpl, blockReward, blockRewardImpl
  let votingImpl, voting
  let owner = accounts[0]
  let validators = [accounts[1], accounts[2], accounts[3], accounts[4], accounts[5], accounts[6], accounts[7], accounts[8]]

  let voteStartAfterNumberOfCycles, voteCyclesDuration

  beforeEach(async () => {
    // Consensus
    consensusImpl = await Consensus.new()
    proxy = await EternalStorageProxy.new(ZERO_ADDRESS, consensusImpl.address)
    consensus = await Consensus.at(proxy.address)
    await consensus.initialize(owner)

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
    await blockReward.initialize(toWei(toBN(300000000000000000 || 0), 'gwei'))

    // Voting
    votingImpl = await Voting.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, votingImpl.address)
    voting = await Voting.at(proxy.address)

    // Initialize ProxyStorage
    await proxyStorage.initializeAddresses(
      blockReward.address,
      voting.address
    )

    await consensus.setNewValidatorSetMock(validators)
    await consensus.setStakeAmountMockGroup(validators)
    await consensus.setFinalizedMock(false, {from: owner})
    await consensus.setSystemAddressMock(owner, {from: owner})
    await consensus.finalizeChange().should.be.fulfilled

    true.should.be.equal(await voting.isValidVotingKey(validators[0]))
    true.should.be.equal(await voting.isValidVotingKey(validators[1]))
    true.should.be.equal(await voting.isValidVotingKey(validators[2]))
    true.should.be.equal(await voting.isValidVotingKey(validators[3]))
    true.should.be.equal(await voting.isValidVotingKey(validators[4]))
    true.should.be.equal(await voting.isValidVotingKey(validators[5]))
    true.should.be.equal(await voting.isValidVotingKey(validators[6]))
    true.should.be.equal(await voting.isValidVotingKey(validators[7]))
  })

  describe('initialize', async () => {
    it('should be successful', async () => {
      await voting.initialize().should.be.fulfilled
      toBN(MIN_BALLOT_DURATION_CYCLES).should.be.bignumber.equal(await voting.getMinBallotDurationCycles())
    })
  })

  describe('newBallot', async () => {
    beforeEach(async () => {
      await voting.initialize().should.be.fulfilled
      voteStartAfterNumberOfCycles = 1
      voteCyclesDuration = 10
    })
    it('should be successful', async () => {
      let id = await voting.getNextBallotId()
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.CONSENSUS
      let currentCycleEndBlock = await consensus.getCurrentCycleEndBlock()
      let voteStartAfterNumberOfBlocks = toBN(voteStartAfterNumberOfCycles).mul(toBN(CYCLE_DURATION_BLOCKS))
      let startBlock = currentCycleEndBlock.add(voteStartAfterNumberOfBlocks)
      let voteEndAfterNumberOfBlocks = toBN(voteCyclesDuration).mul(toBN(CYCLE_DURATION_BLOCKS))
      let endBlock = startBlock.add(voteEndAfterNumberOfBlocks)

      let {logs} = await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('BallotCreated')
      logs[0].args['id'].should.be.bignumber.equal(toBN(id))
      logs[0].args['creator'].should.be.equal(validators[0])
      let ballotInfo = await voting.getBallotInfo(id, validators[0])
      ballotInfo.startBlock.should.be.bignumber.equal(startBlock)
      ballotInfo.endBlock.should.be.bignumber.equal(endBlock)
      ballotInfo.isFinalized.should.be.equal(false)
      ballotInfo.proposedValue.should.be.equal(proposedValue)
      ballotInfo.contractType.should.be.bignumber.equal(toBN(contractType))
      ballotInfo.creator.should.be.equal(validators[0])
      ballotInfo.description.should.be.equal('description')
      ballotInfo.canBeFinalizedNow.should.be.equal(false)
      ballotInfo.alreadyVoted.should.be.equal(false)
      toBN(QUORUM_STATES.IN_PROGRESS).should.be.bignumber.equal(await voting.getQuorumState(id))
    })
    it('should fail if not called by valid voting key', async () => {
      let nonValidatorKey = owner
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.CONSENSUS
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: nonValidatorKey}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if duration is invalid', async () => {
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.CONSENSUS

      // require(_startAfterNumberOfCycles > 0);
      await voting.newBallot(0, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)

      // require (_cyclesDuration > 0);
      await voting.newBallot(voteStartAfterNumberOfCycles, 0, contractType, proposedValue, 'description', {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)

      // require(_cyclesDuration >= getMinBallotDurationCycles());
      let minBallotDurationCycles = await voting.getMinBallotDurationCycles()
      await voting.newBallot(voteStartAfterNumberOfCycles, minBallotDurationCycles.sub(toBN(1)), contractType, proposedValue, 'description', {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)

      // require(_cyclesDuration <= getMaxBallotDurationCycles());
      let maxBallotDurationCycles = await voting.getMaxBallotDurationCycles()
      await voting.newBallot(voteStartAfterNumberOfCycles, maxBallotDurationCycles.add(toBN(1)), contractType, proposedValue, 'description', {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if proposed value is invalid', async () => {
      // require(_proposedValue != address(0));
      let proposedValue = ZERO_ADDRESS
      let contractType = CONTRACT_TYPES.CONSENSUS
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if contract type is invalid', async () => {
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.INVALID
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if creating ballot over the ballots limit', async () => {
      let maxLimitOfBallots = (await voting.MAX_LIMIT_OF_BALLOTS()).toNumber()
      let validatorsCount = (await consensus.currentValidatorsLength()).toNumber()
      let ballotLimitPerValidator = (await voting.getBallotLimitPerValidator()).toNumber()
      ballotLimitPerValidator.should.be.equal(Math.floor(maxLimitOfBallots / validatorsCount))
      // create ballots successfully up to the limit
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.CONSENSUS
      for (let i = 0; i < ballotLimitPerValidator; i++) {
        let {logs} = await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled
      }
      // create a ballot over the limit should fail
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
      // create a ballot with different key successfully
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[1]}).should.be.fulfilled
    })
  })

  describe('vote', async () => {
    let id, proposedValue, contractType
    beforeEach(async () => {
      await voting.initialize().should.be.fulfilled
      voteStartAfterNumberOfCycles = 1
      voteCyclesDuration = 10
      id = await voting.getNextBallotId()
      proposedValue = RANDOM_ADDRESS
      contractType = CONTRACT_TYPES.CONSENSUS
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled
    })
    it('should vote "accept" successfully', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      let {logs} = await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Vote')
      logs[0].args['id'].should.be.bignumber.equal(id)
      logs[0].args['decision'].should.be.bignumber.equal(toBN(ACTION_CHOICES.ACCEPT))
      logs[0].args['voter'].should.be.equal(validators[0])
      toBN(ACTION_CHOICES.ACCEPT).should.be.bignumber.equal(await voting.getVoterChoice(id, validators[0]))
    })
    it('should vote "reject" successfully', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      let {logs} = await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Vote')
      logs[0].args['id'].should.be.bignumber.equal(id)
      logs[0].args['decision'].should.be.bignumber.equal(toBN(ACTION_CHOICES.REJECT))
      logs[0].args['voter'].should.be.equal(validators[0])
      toBN(ACTION_CHOICES.REJECT).should.be.bignumber.equal(await voting.getVoterChoice(id, validators[0]))
    })
    it('multiple voters should vote successfully', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
      toBN(ACTION_CHOICES.ACCEPT).should.be.bignumber.equal(await voting.getVoterChoice(id, validators[0]))

      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[1]}).should.be.fulfilled
      toBN(ACTION_CHOICES.ACCEPT).should.be.bignumber.equal(await voting.getVoterChoice(id, validators[1]))

      await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[2]}).should.be.fulfilled
      toBN(ACTION_CHOICES.REJECT).should.be.bignumber.equal(await voting.getVoterChoice(id, validators[2]))

      await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[3]}).should.be.fulfilled
      toBN(ACTION_CHOICES.REJECT).should.be.bignumber.equal(await voting.getVoterChoice(id, validators[3]))
    })
    it('should be successful even if called by non validator', async () => {
      let nonValidatorKey = owner
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: nonValidatorKey}).should.be.fulfilled
      toBN(ACTION_CHOICES.ACCEPT).should.be.bignumber.equal(await voting.getVoterChoice(id, nonValidatorKey))
    })
    it('should fail if voting before start time', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock).sub(toBN(1))
      await advanceBlocks(blocksToAdvance.toNumber())
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if voting after end time', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteEndBlock = await voting.getEndBlock(id)
      let blocksToAdvance = voteEndBlock.sub(currentBlock).add(toBN(1))
      await advanceBlocks(blocksToAdvance.toNumber())
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if trying to vote twice', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if trying to vote with invalid choice', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      await voting.vote(id, ACTION_CHOICES.INVALID, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
      await voting.vote(id, Object.keys(ACTION_CHOICES).length + 1, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if trying to vote for invalid id', async () => {
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      await voting.vote(id.toNumber() + 1, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
      await voting.vote(id.toNumber() - 1, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('onCycleEnd', async () => {
    beforeEach(async () => {
      await voting.initialize().should.be.fulfilled
      voteStartAfterNumberOfCycles = 1
      voteCyclesDuration = 10
    })
    it('should only be called by Consensus', async () => {
      await voting.onCycleEnd([RANDOM_ADDRESS]).should.be.rejectedWith(ERROR_MSG)
      await proxyStorage.setConsensusMock(owner)
      await voting.onCycleEnd([RANDOM_ADDRESS]).should.be.fulfilled
    })
    it('should work when there are no validators (should not happen)', async () => {
      await proxyStorage.setConsensusMock(owner)
      await voting.onCycleEnd([]).should.be.fulfilled
    })
    it('should work when there are no active ballots', async () => {
      await proxyStorage.setConsensusMock(owner)
      toBN(0).should.be.bignumber.equal(await voting.activeBallotsLength())
      let currentValidators = await consensus.getValidators()
      currentValidators.length.should.be.gte(0)
      await voting.onCycleEnd(currentValidators).should.be.fulfilled
    })
    it('should work when there is one active ballot - no votes yet', async () => {
      let currentValidators = await consensus.getValidators()

      let id = await voting.getNextBallotId()
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.CONSENSUS
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber())
      toBN(1).should.be.bignumber.equal(await voting.activeBallotsLength())

      await proxyStorage.setConsensusMock(owner)
      await voting.onCycleEnd(currentValidators).should.be.fulfilled
      toBN(0).should.be.bignumber.equal(await voting.getAccepted(id))
      toBN(0).should.be.bignumber.equal(await voting.getRejected(id))
    })
    
    it('should reject voting that got majority but does not pass the turnout', async () => {
      let currentValidators = await consensus.getValidators()
      let nonValidatorKey = owner
      // create 1st ballot
      let id = await voting.getNextBallotId()
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.BLOCK_REWARD
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled

      let val0stake = (await consensus.stakeAmount(validators[0]))
      await voting.setConsensusMock(owner)
      await consensus.setNewValidatorSetMock(validators)
      await consensus.setSystemAddressMock(owner, {from: owner})
      await voting.onCycleEnd(currentValidators).should.be.fulfilled

      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber() + 1)

      let expected = {
          accepted: toBN(0),
          rejected: toBN(0)
      }

      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled

      expected.accepted.should.be.bignumber.equal(await voting.getAccepted(id))
      expected.rejected.should.be.bignumber.equal(await voting.getRejected(id))

      currentBlock = toBN(await web3.eth.getBlockNumber())
      voteEndBlock = await voting.getEndBlock(id)
      await advanceBlocks(voteEndBlock.sub(currentBlock).add(toBN(1)).toNumber())

      await voting.setConsensusMock(owner)
      await voting.onCycleEnd(currentValidators).should.be.fulfilled

      expected = {
        accepted: toBN(val0stake),
        rejected: toBN(0)
      }

      let accepted = await voting.getAccepted(id)
      let rejected = await voting.getRejected(id)

      expected.accepted.should.be.bignumber.equal(accepted)
      expected.rejected.should.be.bignumber.equal(rejected)
      accepted.should.be.bignumber.greaterThan(rejected)
      
      let ballotInfo = await voting.getBallotInfo(id, validators[0])
      ballotInfo.isFinalized.should.be.equal(true)
      ballotInfo.canBeFinalizedNow.should.be.equal(false)
      ballotInfo.alreadyVoted.should.be.equal(true)
      ballotInfo.belowTurnOut.should.be.equal(true)
      toBN(QUORUM_STATES.REJECTED).should.be.bignumber.equal(await voting.getQuorumState(id))
    })
    
    it('should accept voting that got majority and pass the turnout #2', async () => {
      let currentValidators = await consensus.getValidators()
      let val0stake = (await consensus.stakeAmount(validators[0]))
      let val1stake = (await consensus.stakeAmount(validators[1]))
      let val2stake = (await consensus.stakeAmount(validators[2]))

      // create ballot
      let id = await voting.getNextBallotId()
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.BLOCK_REWARD
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled

      await voting.setConsensusMock(owner)
      await consensus.setNewValidatorSetMock(validators)
      await consensus.setSystemAddressMock(owner, {from: owner})
      await voting.onCycleEnd(currentValidators).should.be.fulfilled

      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber() + 1)

      let expected = {
          accepted: toBN(0),
          rejected: toBN(0)
      }

      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[1]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[2]}).should.be.fulfilled

      expected.accepted.should.be.bignumber.equal(await voting.getAccepted(id))
      expected.rejected.should.be.bignumber.equal(await voting.getRejected(id))
      true.should.be.equal(await voting.isActiveBallot(id))

      currentBlock = toBN(await web3.eth.getBlockNumber())
      voteEndBlock = await voting.getEndBlock(id)
      await advanceBlocks(voteEndBlock.sub(currentBlock).add(toBN(1)).toNumber())

      expected.accepted = val0stake.add(val1stake)
      expected.rejected = val2stake

      await voting.onCycleEnd(currentValidators).should.be.fulfilled
      true.should.be.equal(await voting.getIsFinalized(id))
      expected.accepted.should.be.bignumber.equal(await voting.getAccepted(id))
      expected.rejected.should.be.bignumber.equal(await voting.getRejected(id))
      false.should.be.equal(await voting.isActiveBallot(id))
      
      let ballotInfo = await voting.getBallotInfo(id, validators[0])
      ballotInfo.isFinalized.should.be.equal(true)
      ballotInfo.canBeFinalizedNow.should.be.equal(false)
      ballotInfo.alreadyVoted.should.be.equal(true)
      ballotInfo.belowTurnOut.should.be.equal(false)
      
      toBN(QUORUM_STATES.ACCEPTED).should.be.bignumber.equal(await voting.getQuorumState(id))
    })

    it('should reject a voting that do not got majority and pass the turnout', async () => {
      let currentValidators = await consensus.getValidators()
      let val0stake = (await consensus.stakeAmount(validators[0]))
      let val1stake = (await consensus.stakeAmount(validators[1]))
      let val2stake = (await consensus.stakeAmount(validators[2]))
      let val3stake = (await consensus.stakeAmount(validators[3]))
      let val4stake = (await consensus.stakeAmount(validators[4]))

      // create ballot
      let id = await voting.getNextBallotId()
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.BLOCK_REWARD
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled

      await voting.setConsensusMock(owner)
      await consensus.setNewValidatorSetMock(validators)
      await consensus.setSystemAddressMock(owner, {from: owner})
      await voting.onCycleEnd(currentValidators).should.be.fulfilled

      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(id)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber() + 1)

      let expected = {
          accepted: toBN(0),
          rejected: toBN(0)
      }

      await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[1]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[2]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[3]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[4]}).should.be.fulfilled

      expected.accepted.should.be.bignumber.equal(await voting.getAccepted(id))
      expected.rejected.should.be.bignumber.equal(await voting.getRejected(id))
      true.should.be.equal(await voting.isActiveBallot(id))

      currentBlock = toBN(await web3.eth.getBlockNumber())
      voteEndBlock = await voting.getEndBlock(id)
      await advanceBlocks(voteEndBlock.sub(currentBlock).add(toBN(1)).toNumber())

      expected.rejected =  val0stake.add(val1stake).add(val2stake)
      expected.accepted =  val3stake.add(val4stake)

      await voting.onCycleEnd(currentValidators).should.be.fulfilled
      true.should.be.equal(await voting.getIsFinalized(id))
      expected.accepted.should.be.bignumber.equal(await voting.getAccepted(id))
      expected.rejected.should.be.bignumber.equal(await voting.getRejected(id))
      false.should.be.equal(await voting.isActiveBallot(id))
      
      let ballotInfo = await voting.getBallotInfo(id, validators[0])
      ballotInfo.isFinalized.should.be.equal(true)
      ballotInfo.canBeFinalizedNow.should.be.equal(false)
      ballotInfo.alreadyVoted.should.be.equal(true)
      ballotInfo.belowTurnOut.should.be.equal(false)
      
      toBN(QUORUM_STATES.REJECTED).should.be.bignumber.equal(await voting.getQuorumState(id))
    })

    it('golden flow should work', async () => {
      let currentValidators = await consensus.getValidators()
      let nonValidatorKey = owner
      let decimals = await voting.DECIMALS()
      // create 1st ballot
      let firstBallotId = await voting.getNextBallotId()
      let proposedValue = RANDOM_ADDRESS
      let contractType = CONTRACT_TYPES.BLOCK_REWARD
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled

      // create 2nd ballot
      let secondBallotId = await voting.getNextBallotId()
      await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled

      // create 3rd ballot
      let thirdBallotId = await voting.getNextBallotId()
      await voting.newBallot(voteStartAfterNumberOfCycles*2, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled
      await proxyStorage.setConsensusMock(nonValidatorKey)
      await consensus.setNewValidatorSetMock(validators)
      await consensus.setSystemAddressMock(owner, {from: owner})
      await voting.onCycleEnd(currentValidators).should.be.fulfilled

      // advance blocks until 1sr and 2nd ballots are open
      let currentBlock = toBN(await web3.eth.getBlockNumber())
      let voteStartBlock = await voting.getStartBlock(firstBallotId)
      let blocksToAdvance = voteStartBlock.sub(currentBlock)
      await advanceBlocks(blocksToAdvance.toNumber() + 1)
      true.should.be.equal(await voting.isActiveBallot(firstBallotId))
      true.should.be.equal(await voting.isActiveBallot(secondBallotId))
      false.should.be.equal(await voting.isActiveBallot(thirdBallotId))

      let val0stake = (await consensus.stakeAmount(validators[0]))
      let val1stake = (await consensus.stakeAmount(validators[1]))
      let val2stake = (await consensus.stakeAmount(validators[2]))
      let val3stake = (await consensus.stakeAmount(validators[3]))
      let val4stake = (await consensus.stakeAmount(validators[4]))
      let val5stake = (await consensus.stakeAmount(validators[5]))
      let val6stake = (await consensus.stakeAmount(validators[6]))

      // check votes
      let expected = {
        first: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        second: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        third: {
          accepted: toBN(0),
          rejected: toBN(0)
        }
      }

      let totals = {
        first: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        second: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        third: {
          accepted: toBN(0),
          rejected: toBN(0)
        }
      }

      expected.first.accepted.should.be.bignumber.equal(await voting.getAccepted(firstBallotId))
      expected.first.rejected.should.be.bignumber.equal(await voting.getRejected(firstBallotId))
      expected.second.accepted.should.be.bignumber.equal(await voting.getAccepted(secondBallotId))
      expected.second.rejected.should.be.bignumber.equal(await voting.getRejected(secondBallotId))
      expected.third.accepted.should.be.bignumber.equal(await voting.getAccepted(thirdBallotId))
      expected.third.rejected.should.be.bignumber.equal(await voting.getRejected(thirdBallotId))

      // vote on 1st ballot
      await voting.vote(firstBallotId, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
      await voting.vote(firstBallotId, ACTION_CHOICES.REJECT, {from: validators[1]}).should.be.fulfilled
      await voting.vote(firstBallotId, ACTION_CHOICES.ACCEPT, {from: validators[2]}).should.be.fulfilled
      await voting.vote(firstBallotId, ACTION_CHOICES.ACCEPT, {from: nonValidatorKey}).should.be.fulfilled

      totals.first.accepted = totals.first.accepted.add(val0stake.add(val2stake))
      totals.first.rejected = totals.first.rejected.add(val1stake)

      // vote on 2nd ballot
      await voting.vote(secondBallotId, ACTION_CHOICES.REJECT, {from: validators[0]}).should.be.fulfilled
      await voting.vote(secondBallotId, ACTION_CHOICES.ACCEPT, {from: validators[1]}).should.be.fulfilled
      await voting.vote(secondBallotId, ACTION_CHOICES.REJECT, {from: validators[2]}).should.be.fulfilled
      await voting.vote(secondBallotId, ACTION_CHOICES.ACCEPT, {from: nonValidatorKey}).should.be.fulfilled

      totals.second.accepted = totals.second.accepted.add(val1stake)
      totals.second.rejected = totals.second.rejected.add(val0stake.add(val2stake))

      // check votes
      expected = {
        first: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        second: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        third: {
          accepted: toBN(0),
          rejected: toBN(0)
        }
      }
      expected.first.accepted.should.be.bignumber.equal(await voting.getAccepted(firstBallotId))
      expected.first.rejected.should.be.bignumber.equal(await voting.getRejected(firstBallotId))
      expected.second.accepted.should.be.bignumber.equal(await voting.getAccepted(secondBallotId))
      expected.second.rejected.should.be.bignumber.equal(await voting.getRejected(secondBallotId))
      expected.third.accepted.should.be.bignumber.equal(await voting.getAccepted(thirdBallotId))
      expected.third.rejected.should.be.bignumber.equal(await voting.getRejected(thirdBallotId))

      // end cycle and check votes
      currentBlock = toBN(await web3.eth.getBlockNumber())
      let currentCycleEndBlock = await consensus.getCurrentCycleEndBlock()
      await advanceBlocks(currentCycleEndBlock.sub(currentBlock).toNumber())
      await voting.setConsensusMock(owner)
      await voting.onCycleEnd(currentValidators).should.be.fulfilled
      expected = {
        first: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        second: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        third: {
          accepted: toBN(0),
          rejected: toBN(0)
        }
      }
      expected.first.accepted.should.be.bignumber.equal(await voting.getAccepted(firstBallotId))
      expected.first.rejected.should.be.bignumber.equal(await voting.getRejected(firstBallotId))
      expected.second.accepted.should.be.bignumber.equal(await voting.getAccepted(secondBallotId))
      expected.second.rejected.should.be.bignumber.equal(await voting.getRejected(secondBallotId))
      expected.third.accepted.should.be.bignumber.equal(await voting.getAccepted(thirdBallotId))
      expected.third.rejected.should.be.bignumber.equal(await voting.getRejected(thirdBallotId))

      // advance until 3rd ballot is open
      currentBlock = toBN(await web3.eth.getBlockNumber())
      voteStartBlock = await voting.getStartBlock(thirdBallotId)
      await advanceBlocks(voteStartBlock.sub(currentBlock).toNumber() + 1)
      true.should.be.equal(await voting.isActiveBallot(firstBallotId))
      true.should.be.equal(await voting.isActiveBallot(secondBallotId))
      true.should.be.equal(await voting.isActiveBallot(thirdBallotId))

      // vote on 1st ballot
      await voting.vote(firstBallotId, ACTION_CHOICES.ACCEPT, {from: validators[3]}).should.be.fulfilled
      await voting.vote(firstBallotId, ACTION_CHOICES.REJECT, {from: validators[4]}).should.be.fulfilled
      await voting.vote(firstBallotId, ACTION_CHOICES.ACCEPT, {from: validators[5]}).should.be.fulfilled
      await voting.vote(firstBallotId, ACTION_CHOICES.ACCEPT, {from: validators[6]}).should.be.fulfilled

      totals.first.accepted = totals.first.accepted.add(val3stake.add(val5stake.add(val6stake)))
      totals.first.rejected = totals.first.rejected.add(val4stake)

      // vote on 2nd ballot
      await voting.vote(secondBallotId, ACTION_CHOICES.REJECT, {from: validators[3]}).should.be.fulfilled
      await voting.vote(secondBallotId, ACTION_CHOICES.ACCEPT, {from: validators[4]}).should.be.fulfilled

      totals.second.accepted = totals.second.accepted.add(val4stake)
      totals.second.rejected = totals.second.rejected.add(val3stake)

      // vote on 3rd ballot
      await voting.vote(thirdBallotId, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
      await voting.vote(thirdBallotId, ACTION_CHOICES.ACCEPT, {from: validators[1]}).should.be.fulfilled
      await voting.vote(thirdBallotId, ACTION_CHOICES.ACCEPT, {from: validators[2]}).should.be.fulfilled
      await voting.vote(thirdBallotId, ACTION_CHOICES.REJECT, {from: nonValidatorKey}).should.be.fulfilled

      totals.third.accepted = totals.third.accepted.add(val0stake.add(val1stake.add(val2stake)))

      // check votes
      expected = {
        first: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        second: {
          accepted: toBN(0),
          rejected: toBN(0)
        },
        third: {
          accepted: toBN(0),
          rejected: toBN(0)
        }
      }
      expected.first.accepted.should.be.bignumber.equal(await voting.getAccepted(firstBallotId))
      expected.first.rejected.should.be.bignumber.equal(await voting.getRejected(firstBallotId))
      expected.second.accepted.should.be.bignumber.equal(await voting.getAccepted(secondBallotId))
      expected.second.rejected.should.be.bignumber.equal(await voting.getRejected(secondBallotId))
      expected.third.accepted.should.be.bignumber.equal(await voting.getAccepted(thirdBallotId))
      expected.third.rejected.should.be.bignumber.equal(await voting.getRejected(thirdBallotId))

      // make non validator a validator so its votes will count as well
      validators.push(nonValidatorKey)
      await proxyStorage.setConsensusMock(consensus.address)
      await consensus.setNewValidatorSetMock(validators)
      await consensus.setSystemAddressMock(owner, {from: owner})
      await consensus.setFinalizedMock(false, {from: owner})
      await consensus.finalizeChange().should.be.fulfilled
      currentValidators = await consensus.getValidators()
      currentValidators[8].should.be.equal(nonValidatorKey)
      true.should.be.equal(await voting.isValidVotingKey(validators[8]))

      // advance until 1st and 2nd ballots are closed
      currentBlock = toBN(await web3.eth.getBlockNumber())
      voteEndBlock = await voting.getEndBlock(firstBallotId)
      await advanceBlocks(voteEndBlock.sub(currentBlock).add(toBN(1)).toNumber())
      
      false.should.be.equal(await voting.isActiveBallot(firstBallotId))
      false.should.be.equal(await voting.isActiveBallot(secondBallotId))
      true.should.be.equal(await voting.isActiveBallot(thirdBallotId))

      // end cycle and check votes
      currentBlock = toBN(await web3.eth.getBlockNumber())
      currentCycleEndBlock = await consensus.getCurrentCycleEndBlock()
      await advanceBlocks(currentCycleEndBlock.sub(currentBlock).toNumber())
      //await proxyStorage.setConsensusMock(owner)
      await voting.setConsensusMock(owner)
      await voting.onCycleEnd(currentValidators).should.be.fulfilled
      expected = {
        first: {
          accepted: toBN(totals.first.accepted),
          rejected: toBN(totals.first.rejected)
        },
        second: {
          accepted: toBN(totals.second.accepted),
          rejected: toBN(totals.second.rejected)
        },
        third: {
          accepted: toBN(0),
          rejected: toBN(0)
        }
      }
      expected.first.accepted.should.be.bignumber.equal(await voting.getAccepted(firstBallotId))
      expected.first.rejected.should.be.bignumber.equal(await voting.getRejected(firstBallotId))
      expected.second.accepted.should.be.bignumber.equal(await voting.getAccepted(secondBallotId))
      expected.second.rejected.should.be.bignumber.equal(await voting.getRejected(secondBallotId))
      expected.third.accepted.should.be.bignumber.equal(await voting.getAccepted(thirdBallotId))
      expected.third.rejected.should.be.bignumber.equal(await voting.getRejected(thirdBallotId))

      // check 1st and 2nd ballots have been finalized
      true.should.be.equal(await voting.getIsFinalized(firstBallotId))
      true.should.be.equal(await voting.getIsFinalized(secondBallotId))
      false.should.be.equal(await voting.getIsFinalized(thirdBallotId))

      await proxyStorage.upgradeBlockRewardMock(blockRewardImpl.address)

      // vote on 3rd ballot
      await voting.vote(thirdBallotId, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.rejectedWith(ERROR_MSG)
      await voting.vote(thirdBallotId, ACTION_CHOICES.ACCEPT, {from: validators[3]}).should.be.fulfilled
      await voting.vote(thirdBallotId, ACTION_CHOICES.REJECT, {from: validators[4]}).should.be.fulfilled

      totals.third.accepted = totals.third.accepted.add(val3stake)
      totals.third.rejected = totals.third.rejected.add(val4stake)

      // advance until 3rd ballot is closed
      currentBlock = toBN(await web3.eth.getBlockNumber())
      voteEndBlock = await voting.getEndBlock(thirdBallotId)
      await advanceBlocks(voteEndBlock.sub(currentBlock).add(toBN(1)).toNumber())
      false.should.be.equal(await voting.isActiveBallot(thirdBallotId))

      // end cycle and check votes
      currentBlock = toBN(await web3.eth.getBlockNumber())
      currentCycleEndBlock = await consensus.getCurrentCycleEndBlock()
      await advanceBlocks(currentCycleEndBlock.sub(currentBlock).toNumber())
      await voting.setConsensusMock(owner)
      await voting.onCycleEnd(currentValidators).should.be.fulfilled
      expected = {
        first: {
          accepted: totals.first.accepted,
          rejected: totals.first.rejected
        },
        second: {
          accepted: totals.second.accepted,
          rejected: totals.second.rejected
        },
        third: {
          accepted: totals.third.accepted,
          rejected: totals.third.rejected
        }
      }
      expected.first.accepted.should.be.bignumber.equal(await voting.getAccepted(firstBallotId))
      expected.first.rejected.should.be.bignumber.equal(await voting.getRejected(firstBallotId))
      expected.second.accepted.should.be.bignumber.equal(await voting.getAccepted(secondBallotId))
      expected.second.rejected.should.be.bignumber.equal(await voting.getRejected(secondBallotId))
      expected.third.accepted.should.be.bignumber.equal(await voting.getAccepted(thirdBallotId))
      expected.third.rejected.should.be.bignumber.equal(await voting.getRejected(thirdBallotId))

      // check 3rd ballot has been finalized
      true.should.be.equal(await voting.getIsFinalized(thirdBallotId))
    })
    it('golden flow should work wih a lot of validators, a lot of votes', async () => {
      // TODO
    })
  })

  // describe('finalize', async () => {
  //   let currentValidators
  //   beforeEach(async () => {
  //     await voting.initialize().should.be.fulfilled
  //     voteStartAfterNumberOfCycles = 1
  //     voteCyclesDuration = 10
  //     currentValidators = await consensus.getValidators()
  //   })
  //   it('should change to proposed value successfully if quorum is reached', async () => {
  //     let id = await voting.getNextBallotId()
  //     let proposedValue = RANDOM_ADDRESS
  //     let contractType = CONTRACT_TYPES.BLOCK_REWARD
  //     await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled
  //     let currentBlock = toBN(await web3.eth.getBlockNumber())
  //     let voteStartBlock = await voting.getStartBlock(id)
  //     let blocksToAdvance = voteStartBlock.sub(currentBlock)
  //     await advanceBlocks(blocksToAdvance.toNumber())
  //     await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
  //     await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[1]}).should.be.fulfilled
  //     await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[2]}).should.be.fulfilled
  //     let voteEndBlock = await voting.getEndBlock(id)
  //     blocksToAdvance = voteEndBlock.sub(currentBlock).add(toBN(1))
  //     await advanceBlocks(blocksToAdvance.toNumber())
  //     await proxyStorage.setConsensusMock(owner)
  //     let {logs} = await voting.onCycleEnd(currentValidators).should.be.fulfilled
  //     logs.length.should.be.equal(1)
  //     logs[0].event.should.be.equal('BallotFinalized')
  //     logs[0].args['id'].should.be.bignumber.equal(id)
  //     let ballotInfo = await voting.getBallotInfo(id, validators[0])
  //     ballotInfo.startBlock.should.be.bignumber.equal(voteStartBlock)
  //     ballotInfo.endBlock.should.be.bignumber.equal(voteEndBlock)
  //     ballotInfo.isFinalized.should.be.equal(true)
  //     ballotInfo.proposedValue.should.be.equal(proposedValue)
  //     ballotInfo.contractType.should.be.bignumber.equal(toBN(contractType))
  //     ballotInfo.creator.should.be.equal(validators[0])
  //     ballotInfo.description.should.be.equal('description')
  //     ballotInfo.canBeFinalizedNow.should.be.equal(false)
  //     ballotInfo.alreadyVoted.should.be.equal(true)
  //     toBN(QUORUM_STATES.ACCEPTED).should.be.bignumber.equal(await voting.getQuorumState(id))
  //     proposedValue.should.be.equal(await (await EternalStorageProxy.at(await proxyStorage.getBlockReward())).getImplementation())
  //   })
  //   it('should not change to proposed value if quorum is not reached', async () => {
  //     let id = await voting.getNextBallotId()
  //     let proposedValue = RANDOM_ADDRESS
  //     let contractType = CONTRACT_TYPES.BLOCK_REWARD
  //     await voting.newBallot(voteStartAfterNumberOfCycles, voteCyclesDuration, contractType, proposedValue, 'description', {from: validators[0]}).should.be.fulfilled
  //     let currentBlock = toBN(await web3.eth.getBlockNumber())
  //     let voteStartBlock = await voting.getStartBlock(id)
  //     let blocksToAdvance = voteStartBlock.sub(currentBlock)
  //     await advanceBlocks(blocksToAdvance.toNumber())
  //     await voting.vote(id, ACTION_CHOICES.ACCEPT, {from: validators[0]}).should.be.fulfilled
  //     await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[1]}).should.be.fulfilled
  //     await voting.vote(id, ACTION_CHOICES.REJECT, {from: validators[2]}).should.be.fulfilled
  //     let voteEndBlock = await voting.getEndBlock(id)
  //     blocksToAdvance = voteEndBlock.sub(currentBlock).add(toBN(1))
  //     await advanceBlocks(blocksToAdvance.toNumber())
  //     await proxyStorage.setConsensusMock(owner)
  //     let {logs} = await voting.onCycleEnd(currentValidators).should.be.fulfilled
  //     logs.length.should.be.equal(1)
  //     logs[0].event.should.be.equal('BallotFinalized')
  //     logs[0].args['id'].should.be.bignumber.equal(id)
  //     let ballotInfo = await voting.getBallotInfo(id, validators[0])
  //     ballotInfo.startBlock.should.be.bignumber.equal(voteStartBlock)
  //     ballotInfo.endBlock.should.be.bignumber.equal(voteEndBlock)
  //     ballotInfo.isFinalized.should.be.equal(true)
  //     ballotInfo.proposedValue.should.be.equal(proposedValue)
  //     ballotInfo.contractType.should.be.bignumber.equal(toBN(contractType))
  //     ballotInfo.creator.should.be.equal(validators[0])
  //     ballotInfo.description.should.be.equal('description')
  //     ballotInfo.canBeFinalizedNow.should.be.equal(false)
  //     ballotInfo.alreadyVoted.should.be.equal(true)
  //     toBN(QUORUM_STATES.REJECTED).should.be.bignumber.equal(await voting.getQuorumState(id))
  //     proposedValue.should.not.be.equal(await (await EternalStorageProxy.at(await proxyStorage.getBlockReward())).getImplementation())
  //   })
  // })

  // describe('upgradeTo', async () => {
  //   let votingOldImplementation, votingNew
  //   let proxyStorageStub = accounts[13]
  //   beforeEach(async () => {
  //     voting = await Voting.new()
  //     votingOldImplementation = voting.address
  //     proxy = await EternalStorageProxy.new(proxyStorage.address, voting.address)
  //     voting = await Voting.at(proxy.address)
  //     votingNew = await Voting.new()
  //   })
  //   it('should only be called by ProxyStorage', async () => {
  //     await proxy.setProxyStorageMock(proxyStorageStub)
  //     await proxy.upgradeTo(votingNew.address, {from: owner}).should.be.rejectedWith(ERROR_MSG)
  //     let {logs} = await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
  //     logs[0].event.should.be.equal('Upgraded')
  //     await proxy.setProxyStorageMock(proxyStorage.address)
  //   })
  //   it('should change implementation address', async () => {
  //     votingOldImplementation.should.be.equal(await proxy.getImplementation())
  //     await proxy.setProxyStorageMock(proxyStorageStub)
  //     await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
  //     await proxy.setProxyStorageMock(proxyStorage.address)
  //     votingNew.address.should.be.equal(await proxy.getImplementation())
  //   })
  //   it('should increment implementation version', async () => {
  //     let votingOldVersion = await proxy.getVersion()
  //     let votingNewVersion = votingOldVersion.add(toBN(1))
  //     await proxy.setProxyStorageMock(proxyStorageStub)
  //     await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
  //     await proxy.setProxyStorageMock(proxyStorage.address)
  //     votingNewVersion.should.be.bignumber.equal(await proxy.getVersion())
  //   })
  //   it('should work after upgrade', async () => {
  //     await proxy.setProxyStorageMock(proxyStorageStub)
  //     await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
  //     await proxy.setProxyStorageMock(proxyStorage.address)
  //     votingNew = await Voting.at(proxy.address)
  //     false.should.be.equal(await votingNew.isInitialized())
  //     await votingNew.initialize().should.be.fulfilled
  //     true.should.be.equal(await votingNew.isInitialized())
  //   })
  //   it('should use same proxyStorage after upgrade', async () => {
  //     await proxy.setProxyStorageMock(proxyStorageStub)
  //     await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
  //     votingNew = await Voting.at(proxy.address)
  //     proxyStorageStub.should.be.equal(await votingNew.getProxyStorage())
  //   })
  //   it('should use same storage after upgrade', async () => {
  //     let nextBallotId = await voting.getNextBallotId()
  //     let newValue = nextBallotId.toNumber() + 1
  //     await voting.setNextBallotIdMock(newValue)
  //     await proxy.setProxyStorageMock(proxyStorageStub)
  //     await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
  //     votingNew = await Voting.at(proxy.address)
  //     toBN(newValue).should.be.bignumber.equal(await votingNew.getNextBallotId())
  //   })
  // })
})
