const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BlockReward = artifacts.require('BlockRewardMock.sol')
const Voting = artifacts.require('Voting.sol')
const {ERROR_MSG, ZERO_ADDRESS, RANDOM_ADDRESS} = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const INITIAL_SUPPLY = toWei(toBN(300000000000000000 || 0), 'gwei')
const BLOCKS_PER_YEAR = 100
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
      await blockReward.initialize(INITIAL_SUPPLY)
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
      await blockReward.initialize(INITIAL_SUPPLY)
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
    it('should give reward to validator and total supply should be updated', async () => {
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
    it('should give rewards to validator and its delegators', async () => {
      let decimals = await consensus.DECIMALS()
      let minStakeAmount = await consensus.getMinStake()
      let delegatorsCount = accounts.length - 2
      let delegateAmountValue = parseInt(minStakeAmount.div(decimals).toNumber() * 0.99 / delegatorsCount)
      let delegateAmount = toWei(toBN(delegateAmountValue), 'ether')
      let stakeAmountValue = minStakeAmount.div(decimals).toNumber() - delegateAmountValue * delegatorsCount
      let stakeAmount = toWei(toBN(stakeAmountValue), 'ether')
      let fee = 5
      let validator = accounts[1]
      await consensus.sendTransaction({from: validator, value: stakeAmount}).should.be.fulfilled
      for (let i = 2; i < accounts.length; i++) {
        await consensus.delegate(validator, {from: accounts[i], value: delegateAmount}).should.be.fulfilled
      }
      await consensus.setValidatorFeeMock(fee, {from: validator}).should.be.fulfilled
      let validatorFee = await consensus.validatorFee(validator)
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      let initialSupply = await blockReward.getTotalSupply()
      let blockRewardAmount = await blockReward.getBlockRewardAmount()
      let {logs} = await blockReward.reward([validator], [0], {from: mockSystemAddress}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Rewarded')
      let receivers = logs[0].args['receivers']
      let rewards = logs[0].args['rewards']
      receivers.length.should.be.equal(delegatorsCount + 1)
      rewards.length.should.be.equal(receivers.length)
      let expectedRewardForValidator = blockRewardAmount
      let expectedRewardForDelegators = blockRewardAmount.mul(delegateAmount).div(minStakeAmount).mul(decimals.sub(validatorFee)).div(decimals)
      receivers[0].should.be.equal(validator)
      for (let i = 1; i <= delegatorsCount; i++) {
        receivers[i].should.be.equal(accounts[i + 1])
        rewards[i].should.be.bignumber.equal(expectedRewardForDelegators)
        expectedRewardForValidator = expectedRewardForValidator.sub(expectedRewardForDelegators)
      }
      rewards[0].should.be.bignumber.equal(expectedRewardForValidator)
    })
    it('reward amount should update after BLOCKS_PER_YEAR and total yearly inflation should be calculated correctly', async () => {
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})

      let decimals = await blockReward.DECIMALS()
      let initialSupply = await blockReward.getTotalSupply()
      let blocksPerYear = await blockReward.getBlocksPerYear()
      let inflation = await blockReward.getInflation()
      let blockRewardAmount = await blockReward.getBlockRewardAmount()
      // console.log(`initialSupply: ${initialSupply.div(decimals).toNumber()}, blockRewardAmount: ${blockRewardAmount.div(decimals).toNumber()}`)

      // each of the following calls advances a block
      let i = 0
      let blockNumber = await web3.eth.getBlockNumber()
      while (blockNumber % BLOCKS_PER_YEAR !== 0) {
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

  describe('emitRewardedOnCycle', function() {
    beforeEach(async () => {
      await blockReward.initialize(INITIAL_SUPPLY)
    })
    it('should fail if not called by validator', async () => {
      await blockReward.emitRewardedOnCycle({from: nonOwner}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should be successful if `shouldEmitRewardedOnCycle` and `consensus.isFinalized` are true', async () => {
      await blockReward.setShouldEmitRewardedOnCycleMock(false)
      await consensus.setFinalizedMock(false)
      await blockReward.emitRewardedOnCycle({from: owner}).should.be.rejectedWith(ERROR_MSG)

      await blockReward.setShouldEmitRewardedOnCycleMock(true)
      await consensus.setFinalizedMock(false)
      await blockReward.emitRewardedOnCycle({from: owner}).should.be.rejectedWith(ERROR_MSG)

      await blockReward.setShouldEmitRewardedOnCycleMock(false)
      await consensus.setFinalizedMock(true)
      await blockReward.emitRewardedOnCycle({from: owner}).should.be.rejectedWith(ERROR_MSG)

      await blockReward.setShouldEmitRewardedOnCycleMock(true)
      await consensus.setFinalizedMock(true)
      await blockReward.emitRewardedOnCycle({from: owner}).should.be.fulfilled
    })
    it('should be successful and emit event', async () => {
      let BLOCKS_TO_REWARD = 10
      let blockRewardAmount = await blockReward.getBlockRewardAmount()
      let expectedAmount = blockRewardAmount.mul(toBN(BLOCKS_TO_REWARD))

      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      for (let i = 0; i < BLOCKS_TO_REWARD; i++) {
        await blockReward.reward([accounts[3]], [0], {from: mockSystemAddress}).should.be.fulfilled
      }

      await blockReward.setShouldEmitRewardedOnCycleMock(true)
      let {logs} = await blockReward.emitRewardedOnCycle({from: owner}).should.be.fulfilled
      false.should.be.equal(await blockReward.shouldEmitRewardedOnCycle())
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('RewardedOnCycle')
      logs[0].args['amount'].should.be.bignumber.equal(expectedAmount)
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
      await blockRewardNew.initialize(INITIAL_SUPPLY).should.be.fulfilled
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
