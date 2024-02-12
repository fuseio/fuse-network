require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const { assert } = require("chai");

const { VOTING_PROXY, CREDENTIALS_ADDRESS } = process.env;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  let credentialsAddress = ethers.utils.getAddress(CREDENTIALS_ADDRESS);

  // Contracts Factory
  const ConsensusFactory = await ethers.getContractFactory("Consensus");
  const VotingFactory = await ethers.getContractFactory("Voting");

  // Consensus
  const consensusImpl = await ConsensusFactory.deploy();
  await consensusImpl.deployed();
  console.log(`New Consensus Impl: ${consensusImpl.address}`);

  // Verify Consensus
  await hre.run("verify:verify", {
    address: consensusImpl.address,
  });

  // Open Vote
  let votingAddress = ethers.utils.getAddress(VOTING_PROXY);
  console.log(`Voting Contract: ${votingAddress}`);

  const [validator] = await ethers.getSigners();
  console.log(`validator Address: ${validator.address}`);
  console.log(`Credentials Address: ${credentialsAddress}`);
  assert.equal(credentialsAddress, validator.address, "Account Mismatch");

  let voting = VotingFactory.attach(votingAddress);

  let newConcensusAddress = ethers.utils.getAddress(consensusImpl.address);

  const tx = await voting.newBallot(
    1, // startAfterNumberOfCycles - number of cycles (minimum 1) after which the ballot is open for voting
    2, // cyclesDuration - number of cycles (minimum 2) for the ballot to remain open for voting
    1, // contractType: 1 - Consensus, 2 - BlockReward, 3 - ProxyStorage, 4 - Voting
    newConcensusAddress,
    `double jail fix`
  );
  const receipt = await tx.wait();
  const newBallotEvent = receipt.events.find(
    (event) => event.event === "BallotCreated"
  );
  const ballotId = newBallotEvent.args[0];
  const ballotAddress = newBallotEvent.args[1];

  console.log(
    `newBallot - ballotId: ${ballotId}, address: ${ballotAddress}, tx: ${tx.hash}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
