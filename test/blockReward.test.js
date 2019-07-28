const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BlockReward = artifacts.require('BlockRewardMock.sol')
const {ERROR_MSG, ZERO_ADDRESS, RANDOM_ADDRESS} = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const INITIAL_SUPPLY = toWei(toBN(300000000000000000 || 0), 'gwei')
const BLOCKS_PER_YEAR = 6307200
const YEARLY_INFLATION_PERCENTAGE = 5
const SYSTEM_ADDRESS = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE'

contract('BlockReward', async (accounts) => {
  let blockRewardImpl, proxy, blockReward
  let owner = accounts[0]
  let nonOwner = accounts[1]
  let mockSystemAddress = accounts[2]
  let voting = accounts[3]

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

    // BlockReward
    blockRewardImpl = await BlockReward.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, blockRewardImpl.address)
    blockReward = await BlockReward.at(proxy.address)

    // Initialize ProxyStorage
    await proxyStorage.initializeAddresses(
      blockReward.address,
      voting
    )
  })

  describe('initialize', async () => {
    it('default values', async () => {
      await blockReward.initialize(INITIAL_SUPPLY, BLOCKS_PER_YEAR, YEARLY_INFLATION_PERCENTAGE)
      owner.should.equal(await proxy.getOwner())
      toChecksumAddress(SYSTEM_ADDRESS).should.be.equal(toChecksumAddress(await blockReward.getSystemAddress()))
      let decimals = await blockReward.DECIMALS()
      let initialSupply = await blockReward.getTotalSupply()
      let blocksPerYear = await blockReward.getBlocksPerYear()
      let inflation = await blockReward.getInflation()

      INITIAL_SUPPLY.should.be.bignumber.equal(initialSupply)
      toBN(BLOCKS_PER_YEAR).should.be.bignumber.equal(blocksPerYear)
      toBN(YEARLY_INFLATION_PERCENTAGE).should.be.bignumber.equal(inflation)

      let blockRewardAmount = (initialSupply.mul(decimals).mul(inflation).div(toBN(100))).div(blocksPerYear).div(decimals)
      blockRewardAmount.should.be.bignumber.equal(await blockReward.getBlockRewardAmount())
    })
  })

  describe('reward', async () => {
    beforeEach(async () => {
      await blockReward.initialize(INITIAL_SUPPLY, BLOCKS_PER_YEAR, YEARLY_INFLATION_PERCENTAGE)
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
    it('should give reward and total supply should be updated', async () => {
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      let initialSupply = await blockReward.getTotalSupply()
      let blockRewardAmount = await blockReward.getBlockRewardAmount()
      let {logs} = await blockReward.reward([accounts[3]], [0], {from: mockSystemAddress}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Rewarded')
      logs[0].args['receivers'].should.deep.equal([accounts[3]])
      logs[0].args['rewards'][0].should.be.bignumber.equal(blockRewardAmount)
      let expectedSupply = initialSupply.add(blockRewardAmount)
      expectedSupply.should.be.bignumber.equal(await blockReward.getTotalSupply())
    })
    it('reward amount should update after BLOCKS_PER_YEAR and total yearly inflation should be calculated correctly', async () => {
      let BLOCKS_PER_YEAR_MOCK = 3
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await blockReward.initializeMock(INITIAL_SUPPLY, BLOCKS_PER_YEAR_MOCK, YEARLY_INFLATION_PERCENTAGE)

      let decimals = await blockReward.DECIMALS()
      let initialSupply = await blockReward.getTotalSupply()
      let blocksPerYear = await blockReward.getBlocksPerYear()
      let inflation = await blockReward.getInflation()
      let blockRewardAmount = await blockReward.getBlockRewardAmount()
      // console.log(`initialSupply: ${initialSupply.div(decimals).toNumber()}, blockRewardAmount: ${blockRewardAmount.div(decimals).toNumber()}`)

      // each of the following calls advances a block
      let i = 0
      let blockNumber = await web3.eth.getBlockNumber()
      while (blockNumber % BLOCKS_PER_YEAR_MOCK !== 0) {
        // console.log('block #', blockNumber)
        await blockReward.reward([accounts[3]], [0], {from: mockSystemAddress}).should.be.fulfilled
        blockNumber = await web3.eth.getBlockNumber()
        i++
      }
      // console.log('i', i)

      let totalSupply = await blockReward.getTotalSupply()
      let newBlockRewardAmount = await blockReward.getBlockRewardAmount()
      // console.log(`totalSupply: ${totalSupply.div(decimals).toNumber()}, newBlockRewardAmount: ${newBlockRewardAmount.div(decimals).toNumber()}`)
      let expectedSupply = initialSupply
      for (let j = 0; j < i; j++) {
        expectedSupply = expectedSupply.add(blockRewardAmount)
      }
      // console.log(`expectedSupply: ${expectedSupply.div(decimals).toNumber()}`)
      totalSupply.should.be.bignumber.equal(expectedSupply)
      newBlockRewardAmount.should.be.bignumber.equal((totalSupply.mul(decimals).mul(inflation).div(toBN(100))).div(blocksPerYear).div(decimals))
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
      await blockRewardNew.initialize(INITIAL_SUPPLY, BLOCKS_PER_YEAR, YEARLY_INFLATION_PERCENTAGE).should.be.fulfilled
      true.should.be.equal(await blockRewardNew.isInitialized())
    })
    it('should use same proxyStorage after upgrade', async () => {
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      blockRewardNew = await BlockReward.at(proxy.address)
      proxyStorageStub.should.be.equal(await blockRewardNew.getProxyStorage())
    })
    it('should use same storage after upgrade', async () => {
      await blockReward.setSystemAddressMock(RANDOM_ADDRESS, {from: owner})
      await proxy.setProxyStorageMock(proxyStorageStub)
      await proxy.upgradeTo(blockRewardNew.address, {from: proxyStorageStub})
      blockRewardNew = await BlockReward.at(proxy.address)
      RANDOM_ADDRESS.should.be.equal(await blockReward.getSystemAddress())
    })
  })
})
