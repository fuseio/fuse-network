const hre = require("hardhat");
require("dotenv").config();

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

const {
  BLOCK_REWARD_IMPLEMENTATION,
  BLOCK_REWARD_PROXY,
  CONSENSUS_IMPLEMENTATION,
  CONSENSUS_PROXY,
  PROXY_STORAGE_IMPLEMENTATION,
  PROXY_STORAGE_PROXY,
  VOTING_IMPLEMENTATION,
  VOTING_PROXY,
} = process.env;

const contractAddresses = {
  blockRewardImplementation: BLOCK_REWARD_IMPLEMENTATION,
  blockRewardProxy: BLOCK_REWARD_PROXY,
  consensusImplementation: CONSENSUS_IMPLEMENTATION,
  consensusProxy: CONSENSUS_PROXY,
  proxyStorageImplementation: PROXY_STORAGE_IMPLEMENTATION,
  proxyStorageProxy: PROXY_STORAGE_PROXY,
  votingImplementation: VOTING_IMPLEMENTATION,
  votingProxy: VOTING_PROXY,
};

async function main() {
  // Consensus Implementation
  await hre.run("verify:verify", {
    address: contractAddresses.consensusImplementation,
  });
  // Consensus Proxy contract address
  await hre.run("verify:verify", {
    address: contractAddresses.consensusProxy,
    constructorArguments: [
      ZERO_ADDRESS,
      contractAddresses.consensusImplementation,
    ],
  });

  // Proxy Storage Implementation
  await hre.run("verify:verify", {
    address: contractAddresses.proxyStorageImplementation,
  });
  // Proxy Storage Proxy contract address
  await hre.run("verify:verify", {
    address: contractAddresses.proxyStorageProxy,
    constructorArguments: [
      ZERO_ADDRESS,
      contractAddresses.proxyStorageImplementation,
    ],
  });

  // Block Reward Implementation
  await hre.run("verify:verify", {
    address: contractAddresses.blockRewardImplementation,
  });
  // Block Reward Proxy contract address
  await hre.run("verify:verify", {
    address: contractAddresses.blockRewardProxy,
    constructorArguments: [
      contractAddresses.proxyStorageProxy,
      contractAddresses.blockRewardImplementation,
    ],
  });

  // Voting Implementation
  await hre.run("verify:verify", {
    address: contractAddresses.votingImplementation,
  });
  // Voting Proxy contract address
  await hre.run("verify:verify", {
    address: contractAddresses.votingProxy,
    constructorArguments: [
      contractAddresses.proxyStorageProxy,
      contractAddresses.votingImplementation,
    ],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
