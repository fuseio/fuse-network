/* eslint-disable prefer-const */
/* eslint-disable object-curly-spacing */
const Consensus = artifacts.require('ConsensusMock.sol')
const ProxyStorage = artifacts.require('ProxyStorageMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxyMock.sol')
const BlockReward = artifacts.require('BlockRewardMock.sol')
const Voting = artifacts.require('Voting.sol')
const { ERROR_MSG, ZERO_ADDRESS, RANDOM_ADDRESS } = require('./helpers')
const { ZERO, ONE, TWO, THREE, FOUR, TEN } = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const INITIAL_SUPPLY = toWei(toBN(300000000000000000 || 0), 'gwei')
const BLOCKS_PER_YEAR = 100
const YEARLY_INFLATION_PERCENTAGE = 5
const SYSTEM_ADDRESS = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE'

contract('BlockReward', async (accounts) => {
  let blockRewardImpl, proxy, blockReward, consensusImpl, consensus, proxyStorageImpl, proxyStorage
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
    const votingImpl = await Voting.new()
    proxy = await EternalStorageProxy.new(proxyStorage.address, votingImpl.address)
    const voting = await Voting.at(proxy.address)

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
    let minStakeAmount, doubleMinStakeAmount
    beforeEach(async () => {
      await blockReward.initialize(INITIAL_SUPPLY)
      minStakeAmount = await consensus.getMinStake()
      doubleMinStakeAmount = minStakeAmount.mul(TWO)
    })

    describe('#getBlockRewardAmountPerValidator', () => {
      let blockRewardAmount
      let validator, secondValidator
      beforeEach(async () => {
        blockRewardAmount = await blockReward.getBlockRewardAmount()
        validator = accounts[1]
        secondValidator = accounts[2]
      })

      it('block reward with one validator', async () => {
        ZERO.should.be.bignumber.equal(await consensus.totalStakeAmount())

        await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled
        // mocking total supply
        await consensus.setTotalStakeAmountMock(minStakeAmount.mul(TEN))

        const l = await consensus.currentValidatorsLength()
        '1'.should.be.equal(l.toString(10))

        const blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(validator)
        const expectedReward = blockRewardAmount.div(TEN)
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)
      })

      it('block reward of one validator staking 100% of the total stake', async () => {
        await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled
        await consensus.setTotalStakeAmountMock(minStakeAmount)

        const l = await consensus.currentValidatorsLength()
        '1'.should.be.equal(l.toString(10))

        const blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(validator)
        const expectedReward = blockRewardAmount
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)
      })

      it('block reward of 1 validator of 2, staking 10% of the total stake', async () => {
        await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled

        await consensus.setTotalStakeAmountMock(minStakeAmount.mul(TEN))
        await consensus.setCurrentValidatorsLengthMock(TWO)

        const blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(validator)

        // expected reward calculation
        const expectedReward = blockRewardAmount.div(TEN).mul(TWO)
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)
      })

      it('block reward of 1 validator of 2, staking 50% of the total stake', async () => {
        await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled
        await consensus.setTotalStakeAmountMock(minStakeAmount.mul(TEN))
        await consensus.setCurrentValidatorsLengthMock(TWO)

        const l = await consensus.currentValidatorsLength()
        '2'.should.be.equal(l.toString(10))

        const blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(validator)
        // expected reward calculation
        const expectedReward = blockRewardAmount.div(TEN).mul(TWO)
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)
      })

      it('block reward does not change if the propotion stays the same', async () => {
        const validator = accounts[0]
        await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled
        await consensus.setTotalStakeAmountMock(minStakeAmount.mul(TEN))
        await consensus.setCurrentValidatorsLengthMock(TWO)

        const blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(validator)

        // validator stake is 5 * minStakeAmount now
        await consensus.sendTransaction({ from: validator, value: minStakeAmount.mul(toBN(4)) }).should.be.fulfilled
        // total stake is 10 * minStakeAmount now
        await consensus.setTotalStakeAmountMock(minStakeAmount.mul(TEN))

        // expected reward calculation
        const expectedReward = blockRewardAmount.div(TEN).mul(TWO)
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)
      })

      it('block reward for two validators', async () => {
        await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled
        await consensus.sendTransaction({ from: secondValidator, value: minStakeAmount.mul(THREE) }).should.be.fulfilled

        await consensus.setTotalStakeAmountMock(minStakeAmount.mul(FOUR))
        await consensus.setCurrentValidatorsLengthMock(TWO)

        let blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(validator)
        let expectedReward = blockRewardAmount.div(FOUR).mul(TWO)
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)

        blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(secondValidator)
        expectedReward = blockRewardAmount.mul(THREE).div(FOUR).mul(TWO)
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)
      })

      it('block reward without the total stake', async () => {
        const minStakeAmount = await consensus.getMinStake()

        const validator = accounts[1]
        await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled
        // await consensus.setTotalStakeAmountMock(minStakeAmount)

        const l = await consensus.currentValidatorsLength()
        '1'.should.be.equal(l.toString(10))

        const blockRewardAmountOfV = await blockReward.getBlockRewardAmountPerValidator(validator)
        const expectedReward = blockRewardAmount
        expectedReward.should.be.bignumber.equal(blockRewardAmountOfV)
      })

    })

    it('can only be called by system address', async () => {
      await blockReward.reward([accounts[3]], [0]).should.be.rejectedWith(ERROR_MSG)
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await consensus.sendTransaction({from: owner, value: minStakeAmount}).should.be.fulfilled
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
      const validator = accounts[3]
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await consensus.setTotalStakeAmountMock(minStakeAmount)
      await consensus.sendTransaction({from: validator, value: minStakeAmount}).should.be.fulfilled

      let initialSupply = await blockReward.getTotalSupply()
      let blockRewardAmount = await blockReward.getBlockRewardAmountPerValidator(validator)
      let {logs} = await blockReward.reward([validator], [0], {from: mockSystemAddress}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Rewarded')
      logs[0].args['receivers'].should.deep.equal([validator])
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
      let validator = accounts[0]
      await consensus.sendTransaction({from: validator, value: stakeAmount}).should.be.fulfilled
      for (let i = 2; i < accounts.length; i++) {
        await consensus.delegate(validator, {from: accounts[i], value: delegateAmount}).should.be.fulfilled
      }
      await consensus.setValidatorFeeMock(fee, {from: validator}).should.be.fulfilled
      let validatorFee = await consensus.validatorFee(validator)
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      let initialSupply = await blockReward.getTotalSupply()
      let blockRewardAmount = await blockReward.getBlockRewardAmountPerValidator(validator)
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
      const validator = accounts[0]
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await consensus.setTotalStakeAmountMock(0)
      await consensus.sendTransaction({ from: validator, value: minStakeAmount }).should.be.fulfilled
      let decimals = await blockReward.DECIMALS()
      let initialSupply = await blockReward.getTotalSupply()
      let blocksPerYear = await blockReward.getBlocksPerYear()
      let inflation = await blockReward.getInflation()
      let blockRewardAmount = await blockReward.getBlockRewardAmount()

      // each of the following calls advances a block
      let i = 0
      let blockNumber = await web3.eth.getBlockNumber()
      while (blockNumber % BLOCKS_PER_YEAR !== 0) {
        // console.log('block #', blockNumber)
        await blockReward.reward([validator], [0], {from: mockSystemAddress}).should.be.fulfilled
        blockNumber = await web3.eth.getBlockNumber()
        i++
      }

      let totalSupply = await blockReward.getTotalSupply()
      let newBlockRewardAmount = await blockReward.getBlockRewardAmount()
      let expectedSupply = initialSupply
      for (let j = 0; j < i; j++) {
        expectedSupply = expectedSupply.add(blockRewardAmount)
      }
      totalSupply.should.be.bignumber.equal(expectedSupply)
      newBlockRewardAmount.should.be.bignumber.equal((totalSupply.mul(decimals).mul(inflation).div(toBN(100))).div(blocksPerYear).div(decimals))
    })

    it('call reward with 0 blockReward', async () => {
      const validator = accounts[4]
      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      await consensus.setTotalStakeAmountMock(minStakeAmount)
      let {logs} = await blockReward.reward([validator], [0], {from: mockSystemAddress}).should.be.fulfilled

      ZERO.should.be.bignumber.equal(await blockReward.getBlockRewardAmountPerValidator(validator))

      // await consensus.sendTransaction({from: validator, value: minStakeAmount}).should.be.fulfilled

      // let initialSupply = await blockReward.getTotalSupply()
      // let blockRewardAmount = await blockReward.getBlockRewardAmountPerValidator(validator)
      // let {logs} = await blockReward.reward([validator], [0], {from: mockSystemAddress}).should.be.fulfilled
    })
  })

  describe('emitRewardedOnCycle', function () {
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
      let minStakeAmount = await consensus.getMinStake()
      const validator = accounts[0]
      await consensus.sendTransaction({from: validator, value: minStakeAmount}).should.be.fulfilled

      await blockReward.setSystemAddressMock(mockSystemAddress, {from: owner})
      for (let i = 0; i < BLOCKS_TO_REWARD; i++) {
        await blockReward.reward([validator], [0], {from: mockSystemAddress}).should.be.fulfilled
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
