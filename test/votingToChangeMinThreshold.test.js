const moment = require('moment')
const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BallotsStorage = artifacts.require('BallotsStorage.sol')
const Voting = artifacts.require('VotingToChangeMinThresholdMock.sol')
const {ERROR_MSG, ZERO_AMOUNT, ZERO_ADDRESS, THRESHOLD_TYPES} = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const GLOBAL_VALUES = {
  VOTERS: 3,
  BLOCK_REWARD: toWei(toBN(10), 'ether'),
  MIN_STAKE: toWei(toBN(100), 'ether')
}
const BALLOTS_THRESHOLDS = [GLOBAL_VALUES.VOTERS, GLOBAL_VALUES.BLOCK_REWARD, GLOBAL_VALUES.MIN_STAKE]

const MIN_BALLOT_DURATION_SECONDS = 172800 // 2 days
const MIN_POSSIBLE_THRESHOLD = 3

const BALLOT_TYPES = {
  INVALID: 0,
  MIN_THRESHOLD: 1,
  MIN_STAKE: 2,
  BLOCK_REWARD: 3,
  PROXY_ADDRESS: 4
}

const QUORUM_STATES = {
  INVALID: 0,
  IN_PROGRESS: 1,
  ACCEPTED: 2,
  REJECTED: 3
}

const ACTION_CHOICE = {
  INVALID: 0,
  ACCEPT: 1,
  REJECT: 2
}

let VOTING_START_TIME, VOTING_END_TIME

contract('VotingToChangeMinThreshold', async (accounts) => {
  let proxy
  let ballotsStorageImpl, ballotsStorage
  let votingImpl, voting
  let owner = accounts[0]
  let votingKeys = [accounts[1], accounts[2], accounts[3], accounts[4], accounts[5], accounts[6], accounts[7], accounts[8]]
  let blockReward = accounts[9]
  let votingToChangeBlockReward = accounts[10]
  let votingToChangeMinStake = accounts[11]
  let votingToChangeProxy = accounts[12]

  beforeEach(async () => {
    // Consensus
    consensusImpl = await Consensus.new()
    proxy = await EternalStorageProxy.new(ZERO_ADDRESS, consensusImpl.address)
    consensus = await Consensus.at(proxy.address)
    await consensus.initialize(toWei(toBN(10000), 'ether'), 24*60*60, 10, owner)

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
    await ballotsStorage.initialize(BALLOTS_THRESHOLDS)

    // VotingToChangeMinThreshold
    votingImpl = await Voting.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, votingImpl.address)
    voting = await Voting.at(proxy.address)

    // Initialize ProxyStorage
    await proxyStorage.initializeAddresses(
      blockReward,
      ballotsStorage.address,
      votingToChangeBlockReward,
      votingToChangeMinStake,
      voting.address,
      votingToChangeProxy
    )

    await consensus.setNewValidatorSetMock(votingKeys)
    await consensus.setSystemAddressMock(owner, {from: owner})
    await consensus.finalizeChange().should.be.fulfilled

    true.should.be.equal(await voting.isValidVotingKey(votingKeys[0]))
    true.should.be.equal(await voting.isValidVotingKey(votingKeys[1]))
    true.should.be.equal(await voting.isValidVotingKey(votingKeys[2]))
    true.should.be.equal(await voting.isValidVotingKey(votingKeys[3]))
    true.should.be.equal(await voting.isValidVotingKey(votingKeys[4]))
    true.should.be.equal(await voting.isValidVotingKey(votingKeys[5]))
    true.should.be.equal(await voting.isValidVotingKey(votingKeys[6]))
    true.should.be.equal(await voting.isValidVotingKey(votingKeys[7]))
  })

  describe('initialize', async () => {
    it('should be successful', async () => {
      await voting.initialize(MIN_BALLOT_DURATION_SECONDS, MIN_POSSIBLE_THRESHOLD).should.be.fulfilled
      toBN(MIN_BALLOT_DURATION_SECONDS).should.be.bignumber.equal(await voting.getMinBallotDuration())
      toBN(MIN_POSSIBLE_THRESHOLD).should.be.bignumber.equal(await voting.getMinPossibleThreshold())
    })
    it('should fail if min possible threshold is 0', async () => {
      await voting.initialize(MIN_BALLOT_DURATION_SECONDS, ZERO_AMOUNT).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if min ballot duration is bigger than max ballot duration', async () => {
      let maxBallotDuration = await voting.getMaxBallotDuration()
      await voting.initialize(maxBallotDuration.add(toBN(1)), MIN_POSSIBLE_THRESHOLD).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('newBallot', async () => {
    beforeEach(async () => {
      await voting.initialize(MIN_BALLOT_DURATION_SECONDS, MIN_POSSIBLE_THRESHOLD).should.be.fulfilled
      VOTING_START_TIME = moment.utc().add(30, 'seconds').unix()
      VOTING_END_TIME = moment.utc().add(10, 'days').unix()
    })
    it('should be successful', async () => {
      let id = await voting.getNextBallotId()
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      let {logs} = await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('BallotCreated')
      logs[0].args['id'].should.be.bignumber.equal(toBN(id))
      logs[0].args['creator'].should.be.equal(votingKeys[0])
      let ballotInfo = await voting.getBallotInfo(id, votingKeys[0])
      ballotInfo.startTime.should.be.bignumber.equal(toBN(VOTING_START_TIME))
      ballotInfo.endTime.should.be.bignumber.equal(toBN(VOTING_END_TIME))
      ballotInfo.totalVoters.should.be.bignumber.equal(toBN(0))
      ballotInfo.progress.should.be.bignumber.equal(toBN(0))
      ballotInfo.isFinalized.should.be.equal(false)
      ballotInfo.proposedValue.should.be.bignumber.equal(toBN(proposedValue))
      ballotInfo.creator.should.be.equal(votingKeys[0])
      ballotInfo.description.should.be.equal('description')
      ballotInfo.canBeFinalizedNow.should.be.equal(false)
      ballotInfo.alreadyVoted.should.be.equal(false)
      toBN(QUORUM_STATES.IN_PROGRESS).should.be.bignumber.equal(await voting.getQuorumState(id))
      toBN(0).should.be.bignumber.equal(await voting.getIndex(id))
      toBN(BALLOTS_THRESHOLDS[THRESHOLD_TYPES.VOTERS-1]).should.be.bignumber.equal(await voting.getMinThresholdOfVoters(id))
    })
    it('should fail if not called by valid voting key', async () => {
      let nonVotingKey = owner
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: nonVotingKey}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if times are invalid', async () => {
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1

      // require(_startTime > 0 && _endTime > 0);
      VOTING_START_TIME = 0
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
      VOTING_END_TIME = 0
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)

      // require(_endTime > _startTime && _startTime > getTime());
      VOTING_START_TIME = moment.utc().add(2, 'days').unix()
      VOTING_END_TIME = moment.utc().add(1, 'days').unix()
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)

      VOTING_START_TIME = moment.utc().subtract(30, 'seconds').unix()
      VOTING_END_TIME = moment.utc().add(1, 'days').unix()
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)

      // require(_endTime.sub(_startTime) > getMinBallotDuration());
      let minBallotDurationSeconds = await voting.getMinBallotDuration()
      VOTING_START_TIME = moment.utc().add(30, 'seconds').unix()
      VOTING_END_TIME = moment.utc(VOTING_START_TIME).add(minBallotDurationSeconds - 60, 'seconds').unix()
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)

      // require(_endTime.sub(_startTime) <= getMaxBallotDuration());
      let maxBallotDurationSeconds = await voting.getMaxBallotDuration()
      VOTING_START_TIME = moment.utc().add(30, 'seconds').unix()
      VOTING_END_TIME = moment.utc(VOTING_START_TIME).add(maxBallotDurationSeconds + 60, 'seconds').unix()
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if proposed value is invalid', async () => {
      // require(_proposedValue >= getMinPossibleThreshold());
      let proposedValue = MIN_POSSIBLE_THRESHOLD - 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)

      // require(_proposedValue != getGlobalMinThresholdOfVoters());
      proposedValue = await ballotsStorage.getBallotThreshold(THRESHOLD_TYPES.VOTERS)
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)

      // require(_proposedValue <= getBallotsStorage().getProxyThreshold());
      proposedValue = (await ballotsStorage.getProxyThreshold()).add(toBN(1))
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if proposed value is same as current value (THRESHOLD_TYPES.VOTERS)', async () => {
      let proposedValue = GLOBAL_VALUES.VOTERS
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if creating ballot over the ballots limit', async () => {
      let maxLimitBallot = (await ballotsStorage.getMaxLimitBallot()).toNumber()
      let validatorsCount = (await consensus.currentValidatorsLength()).toNumber()
      let ballotLimitPerValidator = (await ballotsStorage.getBallotLimitPerValidator()).toNumber()
      ballotLimitPerValidator.should.be.equal(Math.floor(maxLimitBallot / validatorsCount))
      // create ballots successfully up to the limit
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      for (let i = 0; i < ballotLimitPerValidator; i++) {
        let {logs} = await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      }
      // create a ballot over the limit should fail
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
      // create a ballot with different voting key successfully
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[1]}).should.be.fulfilled
    })
  })

  describe('vote', async () => {
    let id, proposedValue
    beforeEach(async () => {
      await voting.initialize(MIN_BALLOT_DURATION_SECONDS, MIN_POSSIBLE_THRESHOLD).should.be.fulfilled
      VOTING_START_TIME = moment.utc().add(30, 'seconds').unix()
      VOTING_END_TIME = moment.utc().add(10, 'days').unix()
      id = await voting.getNextBallotId()
      proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
    })
    it('should vote "accept" successfully', async () => {
      await voting.setTime(VOTING_START_TIME)
      let {logs} = await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Vote')
      logs[0].args['id'].should.be.bignumber.equal(id)
      logs[0].args['decision'].should.be.bignumber.equal(toBN(ACTION_CHOICE.ACCEPT))
      logs[0].args['voter'].should.be.equal(votingKeys[0])
      logs[0].args['time'].should.be.bignumber.equal(toBN(VOTING_START_TIME))
      toBN(1).should.be.bignumber.equal((await voting.getBallotInfo(id, votingKeys[0])).progress)
      toBN(1).should.be.bignumber.equal(await voting.getTotalVoters(id))
    })
    it('should vote "reject" successfully', async () => {
      await voting.setTime(VOTING_START_TIME)
      let {logs} = await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Vote')
      logs[0].args['id'].should.be.bignumber.equal(id)
      logs[0].args['decision'].should.be.bignumber.equal(toBN(ACTION_CHOICE.REJECT))
      logs[0].args['voter'].should.be.equal(votingKeys[0])
      logs[0].args['time'].should.be.bignumber.equal(toBN(VOTING_START_TIME))
      toBN(-1).should.be.bignumber.equal((await voting.getBallotInfo(id, votingKeys[0])).progress)
      toBN(1).should.be.bignumber.equal(await voting.getTotalVoters(id))
    })
    it('multiple voters should vote successfully', async () => {
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.fulfilled
      toBN(1).should.be.bignumber.equal((await voting.getBallotInfo(id, votingKeys[0])).progress)
      toBN(1).should.be.bignumber.equal(await voting.getTotalVoters(id))

      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[1]}).should.be.fulfilled
      toBN(2).should.be.bignumber.equal((await voting.getBallotInfo(id, votingKeys[0])).progress)
      toBN(2).should.be.bignumber.equal(await voting.getTotalVoters(id))

      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[2]}).should.be.fulfilled
      toBN(1).should.be.bignumber.equal((await voting.getBallotInfo(id, votingKeys[0])).progress)
      toBN(3).should.be.bignumber.equal(await voting.getTotalVoters(id))

      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[3]}).should.be.fulfilled
      toBN(0).should.be.bignumber.equal((await voting.getBallotInfo(id, votingKeys[0])).progress)
      toBN(4).should.be.bignumber.equal(await voting.getTotalVoters(id))
    })
    it('should fail if not called by valid voting key', async () => {
      let nonVotingKey = owner
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: nonVotingKey}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if voting before start time', async () => {
      await voting.setTime(VOTING_START_TIME - 1)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if voting after end time', async () => {
      await voting.setTime(VOTING_END_TIME + 1)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if trying to vote twice', async () => {
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if trying to vote with invalid choice', async () => {
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id, ACTION_CHOICE.INVALID, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
      await voting.vote(id, Object.keys(ACTION_CHOICE).length + 1, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if trying to vote for invalid id', async () => {
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id.toNumber() + 1, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
      await voting.vote(id.toNumber() - 1, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('finalize', async () => {
    beforeEach(async () => {
      await voting.initialize(MIN_BALLOT_DURATION_SECONDS, MIN_POSSIBLE_THRESHOLD).should.be.fulfilled
      VOTING_START_TIME = moment.utc().add(30, 'seconds').unix()
      VOTING_END_TIME = moment.utc().add(10, 'days').unix()
    })
    it('should change to proposed value successfully if quorum is reached', async () => {
      let id = await voting.getNextBallotId()
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[1]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[2]}).should.be.fulfilled
      await voting.setTime(VOTING_END_TIME + 1)
      let {logs} = await voting.finalize(id, {from: votingKeys[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('BallotFinalized')
      logs[0].args['id'].should.be.bignumber.equal(id)
      logs[0].args['voter'].should.be.equal(votingKeys[0])
      toBN(0).should.be.bignumber.equal(await voting.activeBallotsLength())
      let ballotInfo = await voting.getBallotInfo(id, votingKeys[0])
      ballotInfo.startTime.should.be.bignumber.equal(toBN(VOTING_START_TIME))
      ballotInfo.endTime.should.be.bignumber.equal(toBN(VOTING_END_TIME))
      ballotInfo.totalVoters.should.be.bignumber.equal(toBN(BALLOTS_THRESHOLDS[THRESHOLD_TYPES.VOTERS-1]))
      ballotInfo.progress.should.be.bignumber.equal(toBN(1))
      ballotInfo.isFinalized.should.be.equal(true)
      ballotInfo.proposedValue.should.be.bignumber.equal(toBN(proposedValue))
      ballotInfo.creator.should.be.equal(votingKeys[0])
      ballotInfo.description.should.be.equal('description')
      ballotInfo.canBeFinalizedNow.should.be.equal(false)
      ballotInfo.alreadyVoted.should.be.equal(true)
      toBN(QUORUM_STATES.ACCEPTED).should.be.bignumber.equal(await voting.getQuorumState(id))
      toBN(0).should.be.bignumber.equal(await voting.getIndex(id))
      toBN(proposedValue).should.be.bignumber.equal(await ballotsStorage.getBallotThreshold(THRESHOLD_TYPES.VOTERS))
    })
    it('should not change to proposed value if quorum is not reached', async () => {
      let id = await voting.getNextBallotId()
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[1]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[2]}).should.be.fulfilled
      await voting.setTime(VOTING_END_TIME + 1)
      let {logs} = await voting.finalize(id, {from: votingKeys[0]}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('BallotFinalized')
      logs[0].args['id'].should.be.bignumber.equal(id)
      logs[0].args['voter'].should.be.equal(votingKeys[0])
      toBN(0).should.be.bignumber.equal(await voting.activeBallotsLength())
      let ballotInfo = await voting.getBallotInfo(id, votingKeys[0])
      ballotInfo.startTime.should.be.bignumber.equal(toBN(VOTING_START_TIME))
      ballotInfo.endTime.should.be.bignumber.equal(toBN(VOTING_END_TIME))
      ballotInfo.totalVoters.should.be.bignumber.equal(toBN(BALLOTS_THRESHOLDS[THRESHOLD_TYPES.VOTERS-1]))
      ballotInfo.progress.should.be.bignumber.equal(toBN(-1))
      ballotInfo.isFinalized.should.be.equal(true)
      ballotInfo.proposedValue.should.be.bignumber.equal(toBN(proposedValue))
      ballotInfo.creator.should.be.equal(votingKeys[0])
      ballotInfo.description.should.be.equal('description')
      ballotInfo.canBeFinalizedNow.should.be.equal(false)
      ballotInfo.alreadyVoted.should.be.equal(true)
      toBN(QUORUM_STATES.REJECTED).should.be.bignumber.equal(await voting.getQuorumState(id))
      toBN(0).should.be.bignumber.equal(await voting.getIndex(id))
      toBN(proposedValue).should.not.be.bignumber.equal(await ballotsStorage.getBallotThreshold(THRESHOLD_TYPES.VOTERS))
    })
    it('should fail if trying to finalize twice', async () => {
      let id = await voting.getNextBallotId()
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      await voting.setTime(VOTING_START_TIME)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[1]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[2]}).should.be.fulfilled
      await voting.setTime(VOTING_END_TIME + 1)
      await voting.finalize(id, {from: votingKeys[0]}).should.be.fulfilled
      await voting.finalize(id, {from: votingKeys[0]}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should be allowed after all possible voters have voted even if end time not passed', async () => {
      let id = await voting.getNextBallotId()
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      await voting.setTime(VOTING_START_TIME + MIN_BALLOT_DURATION_SECONDS + 1)
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[0]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[1]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[2]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[3]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[4]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[5]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.ACCEPT, {from: votingKeys[6]}).should.be.fulfilled
      await voting.vote(id, ACTION_CHOICE.REJECT, {from: votingKeys[7]}).should.be.fulfilled
      await voting.finalize(id, {from: votingKeys[0]}).should.be.fulfilled
    })
    it('should be allowed after end time has passed even if not all voters have voted', async () => {
      let id = await voting.getNextBallotId()
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      await voting.setTime(VOTING_END_TIME + 1)
      await voting.finalize(id, {from: votingKeys[0]}).should.be.fulfilled
    })
    it('should fail if not called by valid voting key', async () => {
      let nonVotingKey = owner
      let id = await voting.getNextBallotId()
      let proposedValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.newBallot(VOTING_START_TIME, VOTING_END_TIME, proposedValue, 'description', {from: votingKeys[0]}).should.be.fulfilled
      await voting.setTime(VOTING_END_TIME + 1)
      await voting.finalize(id, {from: nonVotingKey}).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('upgradeTo', async () => {
    let votingOldImplementation, votingNew
    let proxyStorageStub = accounts[13]
    beforeEach(async () => {
      voting = await Voting.new()
      votingOldImplementation = voting.address
      proxy = await EternalStorageProxy.new(proxyStorage.address, voting.address)
      voting = await Voting.at(proxy.address)
      votingNew = await Voting.new()
    })
    it('should only be called by ProxyStorage', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(votingNew.address, {from: owner}).should.be.rejectedWith(ERROR_MSG)
      let {logs} = await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
      logs[0].event.should.be.equal('Upgraded')
      await proxy.setProxyStorageMock(proxyStorage.address)
    })
    it('should change implementation address', async () => {
      votingOldImplementation.should.be.equal(await proxy.getImplementation())
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      votingNew.address.should.be.equal(await proxy.getImplementation())
    })
    it('should increment implementation version', async () => {
      let votingOldVersion = await proxy.getVersion()
      let votingNewVersion = votingOldVersion.add(toBN(1))
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      votingNewVersion.should.be.bignumber.equal(await proxy.getVersion())
    })
    it('should work after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      votingNew = await Voting.at(proxy.address)
      false.should.be.equal(await votingNew.isInitialized())
      await votingNew.initialize(MIN_BALLOT_DURATION_SECONDS, MIN_POSSIBLE_THRESHOLD).should.be.fulfilled
      true.should.be.equal(await votingNew.isInitialized())
    })
    it('should use same proxyStorage after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
      votingNew = await Voting.at(proxy.address)
      proxyStorageStub.should.be.equal(await votingNew.getProxyStorage())
    })
    it('should use same storage after upgrade', async () => {
      let newValue = MIN_POSSIBLE_THRESHOLD + 1
      await voting.setMinPossibleThresholdMock(newValue)
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(votingNew.address, {from: proxyStorageStub})
      votingNew = await Voting.at(proxy.address)
      toBN(newValue).should.be.bignumber.equal(await votingNew.getMinPossibleThreshold())
    })
  })
})
