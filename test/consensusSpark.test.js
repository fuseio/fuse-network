const Consensus = artifacts.require("Consensus.sol");
const ConsensusSpark = artifacts.require("ConsensusSpark.sol");
const EternalStorageProxy = artifacts.require("EternalStorageProxyMock.sol");
const { ZERO_ADDRESS } = require("./helpers");
const { toBN } = web3.utils;

contract("ConsensusSpark", async (accounts) => {
  const owner = accounts[0];

  it("runs 1 hour (720 block) cycles", async () => {
    const impl = await ConsensusSpark.new();
    const proxy = await EternalStorageProxy.new(ZERO_ADDRESS, impl.address);
    const consensus = await ConsensusSpark.at(proxy.address);
    await consensus.initialize(owner);

    toBN(720).should.be.bignumber.equal(
      await consensus.getCycleDurationBlocks()
    );
    const start = await consensus.getCurrentCycleStartBlock();
    const end = await consensus.getCurrentCycleEndBlock();
    end.sub(start).should.be.bignumber.equal(toBN(720));
  });

  it("leaves mainnet's Consensus on 48 hour cycles", async () => {
    const consensus = await Consensus.new();
    toBN(34560).should.be.bignumber.equal(
      await consensus.getCycleDurationBlocks()
    );
  });

  it("has the same interface as Consensus apart from its cycle length constant", async () => {
    const signatures = (abi) =>
      abi
        .map((item) =>
          `${item.type} ${item.name}(${(item.inputs || [])
            .map((input) => input.type)
            .join(",")})`
        )
        .sort();
    const sparkOnly = signatures(ConsensusSpark.abi).filter(
      (signature) => !signatures(Consensus.abi).includes(signature)
    );
    sparkOnly.should.be.deep.equal(["function SPARK_CYCLE_DURATION_BLOCKS()"]);
    signatures(Consensus.abi)
      .filter((signature) => !signatures(ConsensusSpark.abi).includes(signature))
      .should.be.deep.equal([]);
  });
});
