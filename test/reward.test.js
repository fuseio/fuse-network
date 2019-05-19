const Reward = artifacts.require('RewardMock.sol')
const EternalStorageProxy = artifacts.require('EternalStorageProxy.sol')
const {ERROR_MSG, ZERO_AMOUNT, ZERO_ADDRESS} = require('./helpers')
const {toBN, toWei, toChecksumAddress} = web3.utils

const REWARD = toWei(toBN(1), 'ether')
const REWARD_OTHER = toWei(toBN(2), 'ether')
const SYSTEM_ADDRESS = '0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE'

contract('Reward', async (accounts) => {
  let rewardImpl, proxy, reward
  let owner = accounts[0]
  let nonOwner = accounts[1]
  let mockSystemAddress = accounts[2]

  describe('initialize', async () => {
    beforeEach(async () => {
      rewardImpl = await Reward.new()
      proxy = await EternalStorageProxy.new()
      await proxy.methods['upgradeTo(uint256,address)']('1', rewardImpl.address)
      reward = await Reward.at(proxy.address)
    })
    it('default values', async () => {
      await reward.initialize(REWARD, owner)
      toChecksumAddress(SYSTEM_ADDRESS).should.be.equal(toChecksumAddress(await reward.systemAddress()))
      REWARD.should.be.bignumber.equal(await reward.getReward())
      owner.should.equal(await reward.owner())
    })
    it('owner address not defined', async () => {
      await reward.initialize(REWARD, ZERO_ADDRESS).should.be.rejectedWith(ERROR_MSG)
    })
    it('only owner can set reward', async () => {
      await reward.initialize(REWARD, owner)
      await reward.setReward(REWARD_OTHER, {from: nonOwner}).should.be.rejectedWith(ERROR_MSG)
      REWARD.should.be.bignumber.equal(await reward.getReward())
      await reward.setReward(REWARD_OTHER, {from: owner})
      REWARD_OTHER.should.be.bignumber.equal(await reward.getReward())
    })
    it('can set zero reward', async () => {
      await reward.initialize(REWARD, owner)
      await reward.setReward(ZERO_AMOUNT, {from: owner})
      ZERO_AMOUNT.should.be.bignumber.equal(await reward.getReward())
    })
  })

  describe('reward', async () => {
    beforeEach(async () => {
      rewardImpl = await Reward.new()
      proxy = await EternalStorageProxy.new()
      await proxy.methods['upgradeTo(uint256,address)']('1', rewardImpl.address)
      reward = await Reward.at(proxy.address)
      await reward.initialize(REWARD, owner)
    })
    it('can only be called by system address', async () => {
      await reward.reward([accounts[3]], [0]).should.be.rejectedWith(ERROR_MSG)
      await reward.setSystemAddress(mockSystemAddress, {from: owner})
      await reward.reward([accounts[3]], [0], {from: mockSystemAddress}).should.be.fulfilled
    })
    it('should revert if input array contains more than one item', async () => {
      await reward.setSystemAddress(mockSystemAddress, {from: owner})
      await reward.reward([accounts[3], accounts[4]], [0, 0], {from: mockSystemAddress}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should revert if lengths of input arrays are not equal', async () => {
      await reward.setSystemAddress(mockSystemAddress, {from: owner})
      await reward.reward([accounts[3]], [0, 0], {from: mockSystemAddress}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should revert if `kind` parameter is not 0', async () => {
      await reward.setSystemAddress(mockSystemAddress, {from: owner})
      await reward.reward([accounts[3]], [1], {from: mockSystemAddress}).should.be.rejectedWith(ERROR_MSG)
    })
    it('should give reward and balance should be updated', async () => {
      await reward.setSystemAddress(mockSystemAddress, {from: owner})
      let {logs} = await reward.reward([accounts[3]], [0], {from: mockSystemAddress}).should.be.fulfilled
      logs.length.should.be.equal(1)
      logs[0].event.should.be.equal('Rewarded')
      logs[0].args['receivers'].should.deep.equal([accounts[3]])
      logs[0].args['rewards'][0].should.be.bignumber.equal(REWARD)
    })
  })
})
