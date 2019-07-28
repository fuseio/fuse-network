const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BlockReward = artifacts.require('BlockReward.sol')
const Voting = artifacts.require('Voting.sol')
const {ERROR_MSG, ZERO_ADDRESS} = require('./helpers')
const {toBN, toWei} = web3.utils

contract('ProxyStorage', async (accounts) => {
  let proxyStorageImpl, proxy, proxyStorage
  let owner = accounts[0]
  let nonOwner = accounts[1]
  let blockReward, voting

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

    // BlockReward
    blockRewardImpl = await BlockReward.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
    blockReward = await BlockReward.at(proxy.address)

    // Voting
    votingImpl = await Voting.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, votingImpl.address)
    voting = await Voting.at(proxy.address)
  })

  describe('initialize', async () => {
    it('should be successful', async () => {
      await proxyStorage.initialize(consensus.address).should.be.fulfilled
      true.should.be.equal(await proxyStorage.isInitialized())
      consensus.address.should.be.equal(await proxyStorage.getConsensus())
    })
  })

  describe('initializeAddresses', async () => {
    beforeEach(async () => {
      await proxyStorage.initialize(consensus.address)
    })
    it('should fail if not called from owner', async () => {
      await proxyStorage.initializeAddresses(
        blockReward.address,
        voting.address,
        {from: nonOwner}
      ).should.be.rejectedWith(ERROR_MSG)
    })
    it('should be successful', async () => {
      let {logs} = await proxyStorage.initializeAddresses(
        blockReward.address,
        voting.address,
        {from: owner}
      ).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('ProxyInitialized')
      logs[0].args.consensus.should.be.equal(consensus.address)
      logs[0].args.blockReward.should.be.equal(blockReward.address)
      logs[0].args.voting.should.be.equal(voting.address)

      consensus.address.should.be.equal(await proxyStorage.getConsensus())
      blockReward.address.should.be.equal(await proxyStorage.getBlockReward())
      voting.address.should.be.equal(await proxyStorage.getVoting())
    })
    it('should not be called twice', async () => {
      await proxyStorage.initializeAddresses(
        blockReward.address,
        voting.address,
        {from: owner}
      ).should.be.fulfilled

      await proxyStorage.initializeAddresses(
        blockReward.address,
        voting.address,
        {from: owner}
      ).should.be.rejectedWith(ERROR_MSG)
    })
  })

  describe('upgradeTo', async () => {
    let proxyStorageNew
    let proxyStorageStub = accounts[8]
    beforeEach(async () => {
      proxyStorageNew = await ProxyStorage.new()
      await proxy.setProxyStorageMock(proxyStorageStub)
    })
    it('should only be called by ProxyStorage (this)', async () => {
      await proxy.upgradeTo(proxyStorageNew.address, {from: owner}).should.be.rejectedWith(ERROR_MSG)
      let {logs} = await proxy.upgradeTo(proxyStorageNew.address, {from: proxyStorageStub})
      logs[0].event.should.be.equal('Upgraded')
      await proxy.setProxyStorageMock(proxyStorage.address)
    })
    it('should change implementation address', async () => {
      await proxy.upgradeTo(proxyStorageNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      proxyStorageNew.address.should.be.equal(await proxy.getImplementation())
    })
    it('should increment implementation version', async () => {
      let proxyStorageOldVersion = await proxy.getVersion()
      let proxyStorageNewVersion = proxyStorageOldVersion.add(toBN(1))
      await proxy.upgradeTo(proxyStorageNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      proxyStorageNewVersion.should.be.bignumber.equal(await proxy.getVersion())
    })
    it('should work after upgrade', async () => {
      await proxy.upgradeTo(proxyStorageNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      proxyStorageNew = await ProxyStorage.at(proxy.address)
      false.should.be.equal(await proxyStorageNew.isInitialized())
      await proxyStorageNew.initialize(consensus.address).should.be.fulfilled
      true.should.be.equal(await proxyStorageNew.isInitialized())
    })
  })
})
