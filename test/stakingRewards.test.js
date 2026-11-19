const StakingRewards = artifacts.require("StakingRewards.sol");
const StakingRewardsHostMock = artifacts.require("StakingRewardsHostMock.sol");
const BlockReward = artifacts.require("BlockReward.sol");
const { ZERO_ADDRESS } = require("./helpers");
const { toBN, toWei } = web3.utils;

contract("StakingRewards", async (accounts) => {
  const owner = accounts[0];
  const operator = accounts[1];
  const validator = accounts[2];
  const delegator = accounts[3];
  const stranger = accounts[4];
  const CYCLE = 100;
  const NEXT_CYCLE = 200;

  let host, staking;

  beforeEach(async () => {
    host = await StakingRewardsHostMock.new();
    staking = await StakingRewards.new(host.address, operator, { from: owner });
    await host.setCurrentCycleStartBlock(CYCLE);
  });

  const record = (receivers, weights, cycle = CYCLE) =>
    host.record(staking.address, cycle, receivers, weights);

  const endCycle = () => host.setCurrentCycleStartBlock(NEXT_CYCLE);

  describe("recordBlockReward", async () => {
    it("can only be called by the block reward contract", async () => {
      await staking
        .recordBlockReward(CYCLE, [validator], [1], { from: owner })
        .should.be.rejectedWith("NotBlockReward");
    });

    it("records weights and skips empty entries", async () => {
      await record([validator, ZERO_ADDRESS, delegator], [30, 50, 0]);
      toBN(30).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, validator)
      );
      toBN(0).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, delegator)
      );
      toBN(30).should.be.bignumber.equal(await staking.totalCycleWeights(CYCLE));
    });

    it("records at most maxReceivers receivers", async () => {
      await staking.setRecordLimits(2, 0, { from: owner });
      await record([validator, delegator, stranger], [10, 20, 40]);
      toBN(10).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, validator)
      );
      toBN(20).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, delegator)
      );
      toBN(0).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, stranger)
      );
      toBN(30).should.be.bignumber.equal(await staking.totalCycleWeights(CYCLE));
    });

    it("skips weights below minRecordWeight without using up maxReceivers", async () => {
      await staking.setRecordLimits(2, 10, { from: owner });
      await record([validator, delegator, stranger], [10, 9, 40]);
      toBN(0).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, delegator)
      );
      toBN(40).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, stranger)
      );
      toBN(50).should.be.bignumber.equal(await staking.totalCycleWeights(CYCLE));
    });

    it("emits how many receivers were recorded", async () => {
      await staking.setRecordLimits(1, 0, { from: owner });
      const tx = await record([validator, delegator], [10, 20]);
      const [event] = await staking.getPastEvents("BlockRewardRecorded", {
        fromBlock: tx.receipt.blockNumber,
      });
      event.args.receiversLength.should.be.bignumber.equal(toBN(2));
      event.args.recordedCount.should.be.bignumber.equal(toBN(1));
      event.args.totalWeightAdded.should.be.bignumber.equal(toBN(10));
    });

    it("is ignored while paused", async () => {
      await staking.setPaused(true, { from: owner });
      await record([validator], [10]);
      toBN(0).should.be.bignumber.equal(await staking.totalCycleWeights(CYCLE));
    });

    it("records MAX_RECEIVERS_LIMIT new receivers within BlockReward's gas limit", async () => {
      const limit = (await staking.MAX_RECEIVERS_LIMIT()).toNumber();
      const receivers = [];
      const weights = [];
      for (let i = 1; i <= limit; i++) {
        receivers.push(web3.utils.padLeft(web3.utils.toHex(i), 40));
        weights.push(i);
      }
      await host.record(staking.address, CYCLE, receivers, weights, {
        gas: 29000000,
      });
      const gasUsed = await host.lastRecordGasUsed();
      const blockReward = await BlockReward.new();
      gasUsed.should.be.bignumber.lessThan(
        await blockReward.STAKING_RECORD_GAS_LIMIT()
      );
      toBN(limit).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, receivers[limit - 1])
      );
    });
  });

  describe("setRecordLimits", async () => {
    it("defaults to MAX_RECEIVERS_LIMIT and no minimum weight", async () => {
      (await staking.maxReceivers()).should.be.bignumber.equal(
        await staking.MAX_RECEIVERS_LIMIT()
      );
      toBN(0).should.be.bignumber.equal(await staking.minRecordWeight());
    });

    it("can only be called by the owner", async () => {
      await staking
        .setRecordLimits(10, 0, { from: operator })
        .should.be.rejectedWith("NotOwner");
    });

    it("rejects a maxReceivers of 0 or above MAX_RECEIVERS_LIMIT", async () => {
      const limit = await staking.MAX_RECEIVERS_LIMIT();
      await staking
        .setRecordLimits(0, 0, { from: owner })
        .should.be.rejectedWith("InvalidMaxReceivers");
      await staking
        .setRecordLimits(limit.add(toBN(1)), 0, { from: owner })
        .should.be.rejectedWith("InvalidMaxReceivers");
      await staking.setRecordLimits(limit, 5, { from: owner }).should.be
        .fulfilled;
    });
  });

  describe("finalizeCycleReward", async () => {
    beforeEach(async () => {
      await record([validator, delegator], [30, 10]);
    });

    it("rejects the cycle in progress", async () => {
      await staking
        .finalizeCycleReward(CYCLE, { from: operator, value: 100 })
        .should.be.rejectedWith("CycleNotEnded");
    });

    it("rejects a cycle that hasn't started", async () => {
      await endCycle();
      await staking
        .finalizeCycleReward(NEXT_CYCLE + 1, { from: operator, value: 100 })
        .should.be.rejectedWith("CycleNotEnded");
    });

    it("finalizes a cycle once it has ended", async () => {
      await endCycle();
      await staking.finalizeCycleReward(CYCLE, { from: operator, value: 100 })
        .should.be.fulfilled;
      true.should.be.equal(await staking.cycleFinalized(CYCLE));
      toBN(100).should.be.bignumber.equal(await staking.cycleRewards(CYCLE));
    });

    it("is blocked while paused", async () => {
      await endCycle();
      await staking.setPaused(true, { from: owner });
      await staking
        .finalizeCycleReward(CYCLE, { from: operator, value: 100 })
        .should.be.rejectedWith("ContractPaused");
    });
  });

  describe("claims", async () => {
    const reward = toWei(toBN(4), "ether");

    beforeEach(async () => {
      await record([validator, delegator], [30, 10]);
      await endCycle();
      await staking.finalizeCycleReward(CYCLE, { from: operator, value: reward });
    });

    it("pays each receiver its share", async () => {
      const before = toBN(await web3.eth.getBalance(delegator));
      const tx = await staking.claimReward(CYCLE, { from: delegator });
      const gasPrice = toBN((await web3.eth.getTransaction(tx.tx)).gasPrice);
      const gasCost = gasPrice.mul(toBN(tx.receipt.gasUsed));
      const after = toBN(await web3.eth.getBalance(delegator));
      after.add(gasCost).sub(before).should.be.bignumber.equal(
        reward.div(toBN(4))
      );
    });

    it("keep working while paused", async () => {
      await staking.setPaused(true, { from: owner });
      await staking.claimReward(CYCLE, { from: validator }).should.be.fulfilled;
      await staking.claimRewards([CYCLE], { from: delegator }).should.be
        .fulfilled;
      toBN(0).should.be.bignumber.equal(
        await staking.userCycleWeights(CYCLE, delegator)
      );
    });
  });

  describe("setPaused", async () => {
    it("emits PauseUpdated", async () => {
      const { logs } = await staking.setPaused(true, { from: owner });
      logs[0].event.should.be.equal("PauseUpdated");
      logs[0].args.paused.should.be.equal(true);
    });
  });
});
