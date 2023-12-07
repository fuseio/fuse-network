require("dotenv").config();
const fs = require("fs");

const hre = require("hardhat");
const ethers = hre.ethers;

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

  const EternalStorageProxy = await ethers.getContractFactory(
    "EternalStorageProxy"
  );

  // Consensus
  const Consensus = await ethers.getContractFactory("Consensus");
  consensusImpl = await Consensus.deploy();
  debug(`consensusImpl: ${consensusImpl.address}`);

  proxy = await EternalStorageProxy.deploy(ZERO_ADDRESS, consensusImpl.address);
  debug(`Consensus proxy: ${proxy.address}`);

  consensus = Consensus.attach(proxy.address);
  await consensus.initialize(initialValidatorAddress);

  // ProxyStorage
  const ProxyStorage = await ethers.getContractFactory("ProxyStorage");
  proxyStorageImpl = await ProxyStorage.deploy();
  debug(`proxyStorageImpl: ${proxyStorageImpl.address}`);

  proxy = await EternalStorageProxy.deploy(
    ZERO_ADDRESS,
    proxyStorageImpl.address
  );
  debug(`ProxyStorage proxy: ${proxy.address}`);

  proxyStorage = ProxyStorage.attach(proxy.address);
  await proxyStorage.initialize();

  // BlockReward
  const BlockReward = await ethers.getContractFactory("BlockReward");
  blockRewardImpl = await BlockReward.deploy();
  debug(`blockRewardImpl: ${blockRewardImpl.address}`);

  proxy = await EternalStorageProxy.deploy(
    ZERO_ADDRESS,
    blockRewardImpl.address
  );
  debug(`BlockReward proxy: ${proxy.address}`);

  blockReward = BlockReward.attach(proxy.address);
  await blockReward.initialize();

  // Voting
  const Voting = await ethers.getContractFactory("Voting");
  votingImpl = await Voting.deploy();
  debug(`votingImpl: ${votingImpl.address}`);

  proxy = await EternalStorageProxy.deploy(ZERO_ADDRESS, votingImpl.address);
  debug(`Voting proxy: ${proxy.address}`);

  voting = Voting.attach(proxy.address);
  await voting.initialize();

  console.log(`Consensus implementation: ${consensusImpl.address}`);
  console.log(`Consensus proxy: ${consensus.address}`);
  console.log(`ProxyStorage implementation: ${proxyStorageImpl.address}`);
  console.log(`ProxyStorage proxy: ${proxyStorage.address}`);
  console.log(`BlockReward implementation: ${blockRewardImpl.address}`);
  console.log(`BlockReward proxy: ${blockReward.address}`);
  console.log(`Voting implementation: ${votingImpl.address}`);
  console.log(`Voting proxy: ${voting.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
