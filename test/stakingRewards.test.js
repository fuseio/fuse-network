const StakingRewards = artifacts.require("StakingRewards.sol");
const { ZERO_ADDRESS } = require("./helpers");
const { ZERO, ONE, TWO, THREE } = require("./helpers");
const { toBN, toWei } = web3.utils;

contract("StakingRewards", async (accounts) => {
  let stakingRewards;

  const owner = accounts[0];
  const blockReward = accounts[1];
  const operator = accounts[2];
  const nonOwner = accounts[3];
  const user = accounts[4];
  const secondUser = accounts[5];
  const newOperator = accounts[6];
  const newOwner = accounts[7];
  const cycle = ONE;
  const rewardAmount = toWei(toBN(1), "ether");

  beforeEach(async () => {
    stakingRewards = await StakingRewards.new(blockReward, operator, {
      from: owner,
    });
  });

  describe("constructor", async () => {
    it("sets default values", async () => {
      blockReward.should.equal(await stakingRewards.blockReward());
      owner.should.equal(await stakingRewards.owner());
      operator.should.equal(await stakingRewards.operator());
      false.should.equal(await stakingRewards.paused());
    });

    it("rejects zero addresses", async () => {
      await StakingRewards.new(ZERO_ADDRESS, operator, { from: owner }).should.be
        .rejected;
      await StakingRewards.new(blockReward, ZERO_ADDRESS, { from: owner }).should
        .be.rejected;
    });
  });

  describe("admin", async () => {
    it("allows only the owner to set operator", async () => {
      await stakingRewards.setOperator(newOperator, { from: nonOwner }).should.be
        .rejected;

      const { logs } = await stakingRewards.setOperator(newOperator, {
        from: owner,
      }).should.be.fulfilled;

      newOperator.should.equal(await stakingRewards.operator());
      logs[0].event.should.equal("OperatorUpdated");
      logs[0].args.oldOperator.should.equal(operator);
      logs[0].args.newOperator.should.equal(newOperator);
    });

    it("allows only the owner to transfer ownership", async () => {
      await stakingRewards.transferOwnership(newOwner, { from: nonOwner }).should
        .be.rejected;

      const { logs } = await stakingRewards.transferOwnership(newOwner, {
        from: owner,
      }).should.be.fulfilled;

      newOwner.should.equal(await stakingRewards.owner());
      logs[0].event.should.equal("OwnershipTransferred");
      logs[0].args.oldOwner.should.equal(owner);
      logs[0].args.newOwner.should.equal(newOwner);
    });

    it("allows only the owner to pause and unpause", async () => {
      await stakingRewards.setPaused(true, { from: nonOwner }).should.be.rejected;

      let result = await stakingRewards.setPaused(true, { from: owner }).should.be
        .fulfilled;
      true.should.equal(await stakingRewards.paused());
      result.logs[0].event.should.equal("Paused");
      result.logs[0].args.paused.should.equal(true);

      result = await stakingRewards.setPaused(false, { from: owner }).should.be
        .fulfilled;
      false.should.equal(await stakingRewards.paused());
      result.logs[0].args.paused.should.equal(false);
    });
  });

  describe("recordBlockReward", async () => {
    it("can only be called by the block reward contract", async () => {
      await stakingRewards.recordBlockReward(cycle, [user], [TWO], {
        from: nonOwner,
      }).should.be.rejected;

      await stakingRewards.recordBlockReward(cycle, [user], [TWO], {
        from: blockReward,
      }).should.be.fulfilled;
    });

    it("records valid weights and skips invalid entries", async () => {
      const { logs } = await stakingRewards.recordBlockReward(
        cycle,
        [user, ZERO_ADDRESS, secondUser, user],
        [TWO, THREE, ZERO, ONE],
        { from: blockReward }
      ).should.be.fulfilled;

      THREE.should.be.bignumber.equal(
        await stakingRewards.userCycleWeights(cycle, user)
      );
      ZERO.should.be.bignumber.equal(
        await stakingRewards.userCycleWeights(cycle, secondUser)
      );
      THREE.should.be.bignumber.equal(
        await stakingRewards.totalCycleWeights(cycle)
      );

      logs[0].event.should.equal("BlockRewardRecorded");
      logs[0].args.cycle.should.be.bignumber.equal(cycle);
      logs[0].args.totalWeightAdded.should.be.bignumber.equal(THREE);
      logs[0].args.receiversLength.should.be.bignumber.equal(toBN(4));
      logs[0].args.rewardWeightsLength.should.be.bignumber.equal(toBN(4));
    });

    it("processes only the shorter input length", async () => {
      await stakingRewards.recordBlockReward(cycle, [user, secondUser], [TWO], {
        from: blockReward,
      }).should.be.fulfilled;

      TWO.should.be.bignumber.equal(
        await stakingRewards.userCycleWeights(cycle, user)
      );
      ZERO.should.be.bignumber.equal(
        await stakingRewards.userCycleWeights(cycle, secondUser)
      );
      TWO.should.be.bignumber.equal(
        await stakingRewards.totalCycleWeights(cycle)
      );
    });

    it("does not record when paused or finalized", async () => {
      await stakingRewards.setPaused(true, { from: owner });
      await stakingRewards.recordBlockReward(cycle, [user], [TWO], {
        from: blockReward,
      }).should.be.fulfilled;
      ZERO.should.be.bignumber.equal(
        await stakingRewards.totalCycleWeights(cycle)
      );

      await stakingRewards.setPaused(false, { from: owner });
      await stakingRewards.recordBlockReward(cycle, [user], [TWO], {
        from: blockReward,
      });
      await stakingRewards.finalizeCycleReward(cycle, {
        from: operator,
        value: rewardAmount,
      });
      await stakingRewards.recordBlockReward(cycle, [user], [THREE], {
        from: blockReward,
      }).should.be.fulfilled;

      TWO.should.be.bignumber.equal(
        await stakingRewards.totalCycleWeights(cycle)
      );
    });
  });

  describe("finalizeCycleReward", async () => {
    beforeEach(async () => {
      await stakingRewards.recordBlockReward(cycle, [user], [TWO], {
        from: blockReward,
      });
    });

    it("can be called by the owner or operator", async () => {
      await stakingRewards.finalizeCycleReward(cycle, {
        from: nonOwner,
        value: rewardAmount,
      }).should.be.rejected;

      const { logs } = await stakingRewards.finalizeCycleReward(cycle, {
        from: operator,
        value: rewardAmount,
      }).should.be.fulfilled;

      rewardAmount.should.be.bignumber.equal(
        await stakingRewards.cycleRewards(cycle)
      );
      true.should.equal(await stakingRewards.cycleFinalized(cycle));
      logs[0].event.should.equal("CycleRewardFinalized");
      logs[0].args.cycle.should.be.bignumber.equal(cycle);
      logs[0].args.rewardAmount.should.be.bignumber.equal(rewardAmount);
    });

    it("rejects invalid finalization", async () => {
      await stakingRewards.finalizeCycleReward(cycle, {
        from: owner,
        value: ZERO,
      }).should.be.rejected;

      await stakingRewards.finalizeCycleReward(TWO, {
        from: owner,
        value: rewardAmount,
      }).should.be.rejected;

      await stakingRewards.setPaused(true, { from: owner });
      await stakingRewards.finalizeCycleReward(cycle, {
        from: owner,
        value: rewardAmount,
      }).should.be.rejected;
    });
  });

  describe("claim", async () => {
    beforeEach(async () => {
      await stakingRewards.recordBlockReward(
        cycle,
        [user, secondUser],
        [ONE, THREE],
        {
          from: blockReward,
        }
      );
      await stakingRewards.finalizeCycleReward(cycle, {
        from: operator,
        value: rewardAmount,
      });
    });

    it("returns pending rewards", async () => {
      toBN(toWei("0.25", "ether")).should.be.bignumber.equal(
        await stakingRewards.pendingReward(user, cycle)
      );
      toBN(toWei("0.75", "ether")).should.be.bignumber.equal(
        await stakingRewards.pendingReward(secondUser, cycle)
      );
      ZERO.should.be.bignumber.equal(
        await stakingRewards.pendingReward(nonOwner, cycle)
      );
    });

    it("allows users to claim a finalized reward once", async () => {
      const expectedReward = toBN(toWei("0.25", "ether"));
      const balanceBefore = toBN(await web3.eth.getBalance(user));
      const receipt = await stakingRewards.claimReward(cycle, { from: user })
        .should.be.fulfilled;
      const balanceAfter = toBN(await web3.eth.getBalance(user));
      const tx = await web3.eth.getTransaction(receipt.tx);
      const gasCost = toBN(tx.gasPrice).mul(toBN(receipt.receipt.gasUsed));

      balanceAfter.should.be.bignumber.equal(
        balanceBefore.add(expectedReward).sub(gasCost)
      );
      ZERO.should.be.bignumber.equal(
        await stakingRewards.userCycleWeights(cycle, user)
      );
      receipt.logs[0].event.should.equal("RewardClaimed");
      receipt.logs[0].args.user.should.equal(user);
      receipt.logs[0].args.rewardAmount.should.be.bignumber.equal(expectedReward);

      await stakingRewards.claimReward(cycle, { from: user }).should.be.rejected;
    });

    it("allows claiming multiple cycles", async () => {
      await stakingRewards.recordBlockReward(TWO, [user], [ONE], {
        from: blockReward,
      });
      await stakingRewards.finalizeCycleReward(TWO, {
        from: owner,
        value: rewardAmount,
      });

      await stakingRewards.claimRewards([cycle, TWO], { from: user }).should.be
        .fulfilled;

      ZERO.should.be.bignumber.equal(
        await stakingRewards.userCycleWeights(cycle, user)
      );
      ZERO.should.be.bignumber.equal(
        await stakingRewards.userCycleWeights(TWO, user)
      );
    });

    it("rejects claims for paused, unfinalized, or empty rewards", async () => {
      await stakingRewards.claimReward(TWO, { from: user }).should.be.rejected;
      await stakingRewards.claimReward(cycle, { from: nonOwner }).should.be
        .rejected;

      await stakingRewards.setPaused(true, { from: owner });
      await stakingRewards.claimReward(cycle, { from: user }).should.be.rejected;
    });
  });
});
