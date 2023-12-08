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

  // Contracts Factory
  const ConsensusFactory = await ethers.getContractFactory("Consensus");
  const ProxyStorageFactory = await ethers.getContractFactory("ProxyStorage");
  const BlockRewardFactory = await ethers.getContractFactory("BlockReward");
  const VotingFactory = await ethers.getContractFactory("Voting");
  const EternalStorageProxyFactory = await ethers.getContractFactory(
    "EternalStorageProxy"
  );

  // Consensus
  const consensusImpl = await ConsensusFactory.deploy();
  await consensusImpl.deployed();
  debug(`Consensus Impl: ${consensusImpl.address}`);

  const consensusProxy = await EternalStorageProxyFactory.deploy(
    ZERO_ADDRESS,
    consensusImpl.address
  );
  await consensusProxy.deployed();
  debug(`Consensus Proxy: ${consensusProxy.address}`);

  const consensus = ConsensusFactory.attach(consensusProxy.address);
  debug(`Consensus: ${consensus.address}`);

  const tx = await consensus.initialize(initialValidatorAddress);
  await tx.wait();

  let consensusInitialValidatorAddress = await consensus.getValidators();
  assert.equal(
    initialValidatorAddress,
    consensusInitialValidatorAddress[0].toLowerCase(),
    "InitialValidatorAddress Mismatch"
  );
  debug(`Initial Validator Address: ${initialValidatorAddress}`);

  // ProxyStorage
  const proxyStorageImpl = await ProxyStorageFactory.deploy();
  await proxyStorageImpl.deployed();
  debug(`ProxyStorage Impl: ${proxyStorageImpl.address}`);

  const storageProxy = await EternalStorageProxyFactory.deploy(
    ZERO_ADDRESS,
    proxyStorageImpl.address
  );
  await storageProxy.deployed();
  debug(`ProxyStorage Proxy: ${storageProxy.address}`);

  const proxyStorage = ProxyStorageFactory.attach(storageProxy.address);
  debug(`ProxyStorage: ${proxyStorage.address}`);

  const tx2 = await proxyStorage.initialize(consensus.address);
  await tx2.wait();
  debug(`ProxyStorage - initialize: ${tx2.hash}`);
  assert.equal(
    consensus.address,
    await proxyStorage.getConsensus(),
    "Consensus Mismatch"
  );

  const tx3 = await consensus.setProxyStorage(proxyStorage.address);
  await tx3.wait();
  debug(`Consensus - setProxyStorage: ${tx3.hash}`);
  assert.equal(
    proxyStorage.address,
    await consensus.getProxyStorage(),
    "ProxyStorage Mismatch"
  );

  // BlockReward
  const blockRewardImpl = await BlockRewardFactory.deploy();
  await blockRewardImpl.deployed();
  debug(`BlockReward Impl: ${blockRewardImpl.address}`);

  const blockRewardProxy = await EternalStorageProxyFactory.deploy(
    proxyStorage.address,
    blockRewardImpl.address
  );
  await blockRewardProxy.deployed();
  debug(`BlockReward Proxy: ${blockRewardProxy.address}`);

  const blockReward = BlockRewardFactory.attach(blockRewardProxy.address);
  debug(`BlockReward: ${blockReward.address}`);

  const tx4 = await blockReward.initialize(initialSupply);
  await tx4.wait();
  debug(`BlockReward - initialize: ${tx4.hash}`);

  // Voting
  const votingImpl = await VotingFactory.deploy();
  await votingImpl.deployed();
  debug(`Voting Impl: ${votingImpl.address}`);

  const votingProxy = await EternalStorageProxyFactory.deploy(
    proxyStorage.address,
    votingImpl.address
  );
  await votingProxy.deployed();
  debug(`Voting Proxy: ${votingProxy.address}`);

  const voting = VotingFactory.attach(votingProxy.address);
  debug(`Voting: ${voting.address}`);
  const tx5 = await voting.initialize();
  await tx5.wait();
  debug(`Voting - initialize ${tx5.hash}`);

  // Check ProxyStorage
  assert.equal(
    proxyStorage.address,
    await blockReward.getProxyStorage(),
    "BlockReward ProxyStorage Mismatch"
  );

  assert.equal(
    proxyStorage.address,
    await voting.getProxyStorage(),
    "Voting ProxyStorage Mismatch"
  );

  assert.equal(
    await blockReward.getProxyStorage(),
    await voting.getProxyStorage(),
    "Voting.BlockReward ProxyStorage Mismatch"
  );

  assert.equal(
    await blockReward.getProxyStorage(),
    await consensus.getProxyStorage(),
    "Consensus.BlockReward ProxyStorage Mismatch"
  );

  // Initialize ProxyStorage
  const tx6 = await proxyStorage.initializeAddresses(
    blockReward.address,
    voting.address
  );
  await tx6.wait();
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
    `ProxyStorage - initializeAddresses: ${blockReward.address}, ${voting.address}, ${tx6.hash}`
  );

  console.log(
    `
    Deploying contracts with the account ............. ${deployer.address}
    Block Reward Implementation ...................... ${blockRewardImpl.address}
    Block Reward Proxy ............................... ${blockReward.address}
    Consensus Implementation ......................... ${consensusImpl.address}
    Consensus Proxy .................................. ${consensus.address}
    ProxyStorage Implementation ...................... ${proxyStorageImpl.address}
    ProxyStorage Proxy ............................... ${proxyStorage.address}
    Voting Implementation ............................ ${votingImpl.address}
    Voting Proxy ..................................... ${voting.address}
    `
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
