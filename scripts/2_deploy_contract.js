require("dotenv").config();
const fs = require("fs");
const hre = require("hardhat");
const ethers = hre.ethers;
const { assert } = require("chai");

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const { INITIAL_VALIDATOR_ADDRESS, INITIAL_SUPPLY_GWEI, SAVE_TO_FILE, DEBUG } =
  process.env;

const debug = (msg) => {
  if (DEBUG) console.log(msg);
};

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(`Deploying contracts with the account: ${deployer.address}`);

  let initialValidatorAddress = INITIAL_VALIDATOR_ADDRESS || ZERO_ADDRESS;
  let initialSupply = ethers.utils.parseUnits(
    INITIAL_SUPPLY_GWEI || "0",
    "gwei"
  );

  let proxy;
  let blockReward, blockRewardImpl;
  let consensus, consensusImpl;
  let proxyStorage, proxyStorageImpl;
  let voting, votingImpl;

  // Contracts Factory
  const ConsensusFactory = await ethers.getContractFactory("Consensus");
  const ProxyStorageFactory = await ethers.getContractFactory("ProxyStorage");
  const BlockRewardFactory = await ethers.getContractFactory("BlockReward");
  const VotingFactory = await ethers.getContractFactory("Voting");
  const EternalStorageProxyFactory = await ethers.getContractFactory(
    "EternalStorageProxy"
  );

  // Consensus
  consensusImpl = await ConsensusFactory.deploy();
  debug(`consensusImpl: ${consensusImpl.address}`);

  proxy = await EternalStorageProxyFactory.deploy(
    ZERO_ADDRESS,
    consensusImpl.address
  );
  debug(`proxy: ${proxy.address}`);

  consensus = await ConsensusFactory.attach(proxy.address);
  debug(`consensus: ${consensus.address}`);

  await consensus.initialize(initialValidatorAddress);
  let consensusInitialValidatorAddress = await consensus.getValidators();
  debug(`consensus.getValidators: ${consensusInitialValidatorAddress}`);

  assert.equal(
    initialValidatorAddress,
    consensusInitialValidatorAddress[0].toLowerCase(),
    "InitialValidatorAddress Mismatch"
  );
  debug(`consensus.initialize(initialValidator): ${initialValidatorAddress}`);

  // ProxyStorage
  proxyStorageImpl = await ProxyStorageFactory.deploy();
  debug(`proxyStorageImpl: ${proxyStorageImpl.address}`);

  proxy = await EternalStorageProxyFactory.deploy(
    ZERO_ADDRESS,
    proxyStorageImpl.address
  );
  debug(`proxy: ${proxy.address}`);

  proxyStorage = ProxyStorageFactory.attach(proxy.address);
  debug(`proxyStorage: ${proxyStorage.address}`);

  await proxyStorage.initialize(consensus.address);
  debug(`proxyStorage.initialize: ${consensus.address}`);
  assert.equal(
    consensus.address,
    await proxyStorage.getConsensus(),
    "Consensus Mismatch"
  );

  let proxyStorageConsensus = await proxyStorage.getConsensus();
  debug(`proxyStorage.getConsensus: ${proxyStorageConsensus}`);

  await consensus.setProxyStorage(proxyStorage.address);
  assert.equal(
    proxyStorage.address,
    await consensus.getProxyStorage(),
    "ProxyStorage Mismatch"
  );
  debug(`consensus.setProxyStorage: ${proxyStorage.address}`);

  // BlockReward
  blockRewardImpl = await BlockRewardFactory.deploy();
  debug(`blockRewardImpl: ${blockRewardImpl.address}`);

  proxy = await EternalStorageProxyFactory.deploy(
    ZERO_ADDRESS,
    blockRewardImpl.address
  );
  debug(`proxy: ${proxy.address}`);

  blockReward = BlockRewardFactory.attach(proxy.address);
  debug(`blockReward: ${blockReward.address}`);

  await blockReward.initialize(initialSupply);
  debug(`blockReward.initialize: ${initialSupply}`);

  // Voting
  votingImpl = await VotingFactory.deploy();
  debug(`votingImpl: ${votingImpl.address}`);

  proxy = await EternalStorageProxyFactory.deploy(
    ZERO_ADDRESS,
    votingImpl.address
  );
  debug(`proxy: ${proxy.address}`);

  voting = VotingFactory.attach(proxy.address);
  debug(`voting: ${voting.address}`);
  await voting.initialize();
  debug(`voting.initialize`);

  // Initialize ProxyStorage
  await proxyStorage.initializeAddresses(blockReward.address, voting.address);
  assert.equal(
    blockReward.address,
    await proxyStorage.getBlockReward(),
    "BlockReward Mismatch"
  );
  assert.equal(
    voting.address,
    await proxyStorage.getVoting(),
    "Voting Mismatch"
  );
  debug(
    `proxyStorage.initializeAddresses: ${blockReward.address}, ${voting.address}`
  );

  console.log(
    `
    Block Reward implementation ...................... ${blockRewardImpl.address}
    Block Reward storage ............................. ${blockReward.address}
    Consensus implementation ......................... ${consensusImpl.address}
    Consensus storage ................................ ${consensus.address}
    ProxyStorage implementation ...................... ${proxyStorageImpl.address}
    ProxyStorage storage ............................. ${proxyStorage.address}
    Voting implementation ............................ ${votingImpl.address}
    Voting storage ................................... ${voting.address}
    `
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
