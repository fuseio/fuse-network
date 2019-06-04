const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BallotsStorage = artifacts.require('BallotsStorage.sol')
const {ERROR_MSG, ZERO_AMOUNT, ZERO_ADDRESS, THRESHOLD_TYPES} = require('./helpers')
const {toBN, toWei} = web3.utils

const GLOBAL_VALUES = {
  VOTERS: 3,
  BLOCK_REWARD: toWei(toBN(10), 'ether'),
  MIN_STAKE: toWei(toBN(100), 'ether')
}
const BALLOTS_THRESHOLDS = [GLOBAL_VALUES.VOTERS, GLOBAL_VALUES.BLOCK_REWARD, GLOBAL_VALUES.MIN_STAKE]

contract('BallotsStorage', async (accounts) => {
  let ballotsStorageImpl, proxy, ballotsStorage
  let owner = accounts[0]
  let blockReward = accounts[1]
  let votingToChangeBlockReward = accounts[2]
  let votingToChangeMinStake = accounts[3]
  let votingToChangeMinThreshold = accounts[4]
  let votingToChangeProxy = accounts[5]

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

    // Initialize ProxyStorage
    await proxyStorage.initializeAddresses(
      blockReward,
      ballotsStorage.address,
      votingToChangeBlockReward,
      votingToChangeMinStake,
      votingToChangeMinThreshold,
      votingToChangeProxy
    )
  })

  describe('initialize', async () => {
    it('should be successful', async () => {
      await ballotsStorage.initialize(BALLOTS_THRESHOLDS).should.be.fulfilled
      toBN(BALLOTS_THRESHOLDS[THRESHOLD_TYPES.VOTERS-1]).should.be.bignumber.equal(await ballotsStorage.getBallotThreshold(THRESHOLD_TYPES.VOTERS))
      toBN(BALLOTS_THRESHOLDS[THRESHOLD_TYPES.BLOCK_REWARD-1]).should.be.bignumber.equal(await ballotsStorage.getBallotThreshold(THRESHOLD_TYPES.BLOCK_REWARD))
      toBN(BALLOTS_THRESHOLDS[THRESHOLD_TYPES.MIN_STAKE-1]).should.be.bignumber.equal(await ballotsStorage.getBallotThreshold(THRESHOLD_TYPES.MIN_STAKE))
    })
    it('should fail if thresholds array is empty', async () => {
      await ballotsStorage.initialize([]).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if thresholds array size is different from ThresholdTypes size', async () => {
      await ballotsStorage.initialize([3, 0]).should.be.rejectedWith(ERROR_MSG)
      await ballotsStorage.initialize([3, 0, toWei(toBN(100), 'ether'), 7]).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if threshold type "Voters" is 0', async () => {
      await ballotsStorage.initialize([0, 0, toWei(toBN(100), 'ether')]).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('setBallotThreshold', async () => {
    beforeEach(async () => {
      await ballotsStorage.initialize(BALLOTS_THRESHOLDS)
    })
    it('should be successful', async () => {
      let newValue = 5
      let {logs} = await ballotsStorage.setBallotThreshold(newValue, THRESHOLD_TYPES.VOTERS, {from: votingToChangeMinThreshold})
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('ThresholdChanged')
      logs[0].args['thresholdType'].should.be.bignumber.equal(toBN(THRESHOLD_TYPES.VOTERS))
      logs[0].args['newValue'].should.be.bignumber.equal(toBN(newValue))
    })
    it('should fail if not called from votingToChangeMinThreshold address', async () => {
      await ballotsStorage.setBallotThreshold(5, THRESHOLD_TYPES.VOTERS, {from: owner}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should fail if trying to set threshold 0', async () => {
      let {logs} = await ballotsStorage.setBallotThreshold(0, THRESHOLD_TYPES.VOTERS, {from: votingToChangeMinThreshold})
      logs.length.should.be.equal(0)
    })
    it('should fail if trying to set "Invalid" threshold type', async () => {
      let {logs} = await ballotsStorage.setBallotThreshold(5, THRESHOLD_TYPES.INVALID, {from: votingToChangeMinThreshold})
      logs.length.should.be.equal(0)
    })
    it('should fail if trying to set non-existing threshold type', async () => {
      let {logs} = await ballotsStorage.setBallotThreshold(5, Object.keys(THRESHOLD_TYPES).length + 1, {from: votingToChangeMinThreshold})
      logs.length.should.be.equal(0)
    })
  })

  describe('getProxyThreshold', async () => {
    beforeEach(async () => {
      await ballotsStorage.initialize(BALLOTS_THRESHOLDS)
    })
    it('should get correct value depending on validators count', async () => {
      toBN(1).should.be.bignumber.equal(await ballotsStorage.getProxyThreshold())
      await consensus.setNewValidatorSetMock([accounts[1], accounts[2], accounts[3]])
      await consensus.setSystemAddressMock(owner, {from: owner})
      await consensus.finalizeChange().should.be.fulfilled
      toBN(2).should.be.bignumber.equal(await ballotsStorage.getProxyThreshold())
    })
  })

  describe('getVotingToChangeBlockReward', async () => {
    beforeEach(async () => {
      await ballotsStorage.initialize(BALLOTS_THRESHOLDS)
    })
    it('should return correct address', async () => {
      let newVotingToChangeBlockReward = accounts[6]
      votingToChangeBlockReward.should.be.equal(await ballotsStorage.getVotingToChangeBlockReward())
      await proxyStorage.setVotingToChangeBlockReward(newVotingToChangeBlockReward)
      newVotingToChangeBlockReward.should.be.equal(await ballotsStorage.getVotingToChangeBlockReward())
    })
  })

  describe('getVotingToChangeMinStake', async () => {
    beforeEach(async () => {
      await ballotsStorage.initialize(BALLOTS_THRESHOLDS)
    })
    it('should return correct address', async () => {
      let newVotingToChangeMinStake = accounts[6]
      votingToChangeMinStake.should.be.equal(await ballotsStorage.getVotingToChangeMinStake())
      await proxyStorage.setVotingToChangeMinStake(newVotingToChangeMinStake)
      newVotingToChangeMinStake.should.be.equal(await ballotsStorage.getVotingToChangeMinStake())
    })
  })

  describe('getVotingToChangeMinThreshold', async () => {
    beforeEach(async () => {
      await ballotsStorage.initialize(BALLOTS_THRESHOLDS)
    })
    it('should return correct address', async () => {
      let newVotingToChangeMinThreshold = accounts[6]
      votingToChangeMinThreshold.should.be.equal(await ballotsStorage.getVotingToChangeMinThreshold())
      await proxyStorage.setVotingToChangeMinThreshold(newVotingToChangeMinThreshold)
      newVotingToChangeMinThreshold.should.be.equal(await ballotsStorage.getVotingToChangeMinThreshold())
    })
  })

  describe('getBallotLimitPerValidator', async () => {
    beforeEach(async () => {
      await ballotsStorage.initialize(BALLOTS_THRESHOLDS)
    })
    it('should return correct value depending on validators count', async () => {
      let maxLimit = await ballotsStorage.getMaxLimitBallot()
      let limit = await ballotsStorage.getBallotLimitPerValidator()
      limit.should.be.bignumber.equal(maxLimit)
      await consensus.setNewValidatorSetMock([accounts[1], accounts[2], accounts[3], accounts[4]])
      await consensus.setSystemAddressMock(owner, {from: owner})
      await consensus.finalizeChange().should.be.fulfilled
      limit = await ballotsStorage.getBallotLimitPerValidator()
      limit.should.be.bignumber.equal(toBN(maxLimit/4))
    })
  })

  describe('upgradeTo', async () => {
    let ballotsStorageOldImplementation, ballotsStorageNew
    let proxyStorageStub = accounts[6]
    beforeEach(async () => {
      ballotsStorage = await BallotsStorage.new()
      ballotsStorageOldImplementation = ballotsStorage.address
      proxy = await EternalStorageProxy.new(proxyStorage.address, ballotsStorage.address)
      ballotsStorage = await BallotsStorage.at(proxy.address)
      ballotsStorageNew = await BallotsStorage.new()
    })
    it('should only be called by ProxyStorage', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(ballotsStorageNew.address, {from: owner}).should.be.rejectedWith(ERROR_MSG)
      let {logs} = await proxy.upgradeTo(ballotsStorageNew.address, {from: proxyStorageStub})
      logs[0].event.should.be.equal('Upgraded')
      await proxy.setProxyStorageMock(proxyStorage.address)
    })
    it('should change implementation address', async () => {
      ballotsStorageOldImplementation.should.be.equal(await proxy.getImplementation())
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(ballotsStorageNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      ballotsStorageNew.address.should.be.equal(await proxy.getImplementation())
    })
    it('should increment implementation version', async () => {
      let ballotsStorageOldVersion = await proxy.getVersion()
      let ballotsStorageNewVersion = ballotsStorageOldVersion.add(toBN(1))
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(ballotsStorageNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      ballotsStorageNewVersion.should.be.bignumber.equal(await proxy.getVersion())
    })
    it('should work after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(ballotsStorageNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      ballotsStorageNew = await BallotsStorage.at(proxy.address)
      false.should.be.equal(await ballotsStorageNew.isInitialized())
      await ballotsStorageNew.initialize(BALLOTS_THRESHOLDS).should.be.fulfilled
      true.should.be.equal(await ballotsStorageNew.isInitialized())
    })
    it('should use same proxyStorage after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(ballotsStorageNew.address, {from: proxyStorageStub})
      ballotsStorageNew = await BallotsStorage.at(proxy.address)
      proxyStorageStub.should.be.equal(await ballotsStorageNew.getProxyStorage())
    })
    it('should use same storage after upgrade', async () => {
      let newValue = 5
      await ballotsStorage.setBallotThreshold(newValue, THRESHOLD_TYPES.VOTERS, {from: votingToChangeMinThreshold})
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(ballotsStorageNew.address, {from: proxyStorageStub})
      ballotsStorageNew = await BallotsStorage.at(proxy.address)
      toBN(newValue).should.be.bignumber.equal(await ballotsStorageNew.getBallotThreshold(THRESHOLD_TYPES.VOTERS))
    })
  })
})
