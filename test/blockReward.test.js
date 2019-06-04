const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BlockReward = artifacts.require('BlockRewardMock.sol')
const {ERROR_MSG, ZERO_AMOUNT, ZERO_ADDRESS} = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const REWARD = toWei(toBN(1), 'ether')
const REWARD_OTHER = toWei(toBN(2), 'ether')
const SYSTEM_ADDRESS = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE'

contract('BlockReward', async (accounts) => {
  let blockRewardImpl, proxy, blockReward
  let owner = accounts[0]
  let nonOwner = accounts[1]
  let mockSystemAddress = accounts[2]
  let ballotsStorage = accounts[3]
  let votingToChangeBlockReward = accounts[4]
  let votingToChangeMinStake = accounts[5]
  let votingToChangeMinThreshold = accounts[6]
  let votingToChangeProxy = accounts[7]

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
    blockRewardImpl = await BlockReward.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
    blockReward = await BlockReward.at(proxy.address)

    // Initialize ProxyStorage
    await proxyStorage.initializeAddresses(
      blockReward.address,
      ballotsStorage,
      votingToChangeBlockReward,
      votingToChangeMinStake,
      votingToChangeMinThreshold,
      votingToChangeProxy
    )
  })

  describe('initialize', async () => {
    it('default values', async () => {
      await blockReward.initialize(REWARD)
      owner.should.equal(await proxy.getOwner())
      toChecksumAddress(SYSTEM_ADDRESS).should.be.equal(toChecksumAddress(await blockReward.systemAddress()))
      REWARD.should.be.bignumber.equal(await blockReward.getReward())
    })
  })

  describe('setReward', async () => {
    beforeEach(async () => {
      await blockReward.initialize(REWARD)
    })
    it('only owner can set reward', async () => {
      await blockReward.setReward(REWARD_OTHER, {from: nonOwner}).should.be.rejectedWith(ERROR_MSG)
      REWARD.should.be.bignumber.equal(await blockReward.getReward())
      await blockReward.setReward(REWARD_OTHER, {from: owner})
      REWARD_OTHER.should.be.bignumber.equal(await blockReward.getReward())
    })
    it('can set zero reward', async () => {
      await blockReward.setReward(ZERO_AMOUNT, {from: owner})
      ZERO_AMOUNT.should.be.bignumber.equal(await blockReward.getReward())
    })
  })

  describe('reward', async () => {
    beforeEach(async () => {
      await blockReward.initialize(REWARD)
    })
    it('can only be called by system address', async () => {
      await blockReward.reward([accounts[3]], [0]).should.be.rejectedWith(ERROR_MSG)
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await blockReward.reward([accounts[3]], [0], {from: mockSystemAddress}).should.be.fulfilled
    })
    it('should revert if input array contains more than one item', async () => {
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await blockReward.reward([accounts[3], accounts[4]], [0, 0], {from: mockSystemAddress}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should revert if lengths of input arrays are not equal', async () => {
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await blockReward.reward([accounts[3]], [0, 0], {from: mockSystemAddress}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should revert if "kind" parameter is not 0', async () => {
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await blockReward.reward([accounts[3]], [1], {from: mockSystemAddress}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should give reward and balance should be updated', async () => {
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      let {logs} = await blockReward.reward([accounts[3]], [0], {from: mockSystemAddress}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Rewarded')
      logs[0].args['receivers'].should.deep.equal([accounts[3]])
      logs[0].args['rewards'][0].should.be.bignumber.equal(REWARD)
    })
  })

  describe('upgradeTo', async () => {
    let blockRewardOldImplementation, blockRewardNew
    let proxyStorageStub = accounts[3]
    beforeEach(async () => {
      blockReward = await BlockReward.new()
      blockRewardOldImplementation = blockReward.address
      proxy = await EternalStorageProxy.new(proxyStorage.address, blockReward.address)
      blockReward = await BlockReward.at(proxy.address)
      blockRewardNew = await BlockReward.new()
    })
    it('should only be called by ProxyStorage', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: owner}).should.be.rejectedWith(ERROR_MSG)
      let {logs} = await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      logs[0].event.should.be.equal('Upgraded')
      await proxy.setProxyStorageMock(proxyStorage.address)
    })
    it('should change implementation address', async () => {
      blockRewardOldImplementation.should.be.equal(await proxy.getImplementation())
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      blockRewardNew.address.should.be.equal(await proxy.getImplementation())
    })
    it('should increment implementation version', async () => {
      let blockRewardOldVersion = await proxy.getVersion()
      let blockRewardNewVersion = blockRewardOldVersion.add(toBN(1))
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      blockRewardNewVersion.should.be.bignumber.equal(await proxy.getVersion())
    })
    it('should work after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      await proxy.setProxyStorageMock(proxyStorage.address)
      blockRewardNew = await BlockReward.at(proxy.address)
      false.should.be.equal(await blockRewardNew.isInitialized())
      await blockRewardNew.initialize(REWARD).should.be.fulfilled
      true.should.be.equal(await blockRewardNew.isInitialized())
    })
    it('should use same proxyStorage after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      blockRewardNew = await BlockReward.at(proxy.address)
      proxyStorageStub.should.be.equal(await blockRewardNew.getProxyStorage())
    })
    it('should use same storage after upgrade', async () => {
      await blockReward.setReward(REWARD_OTHER, {from: owner})
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      blockRewardNew = await BlockReward.at(proxy.address)
      REWARD_OTHER.should.be.bignumber.equal(await blockReward.getReward())
    })
  })
})
