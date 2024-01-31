require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const { assert } = require("chai");

const { CONSENSUS_PROXY, CREDENTIALS_ADDRESS, VOTING_PROXY } = process.env;

async function main() {
  let consensusAddress = ethers.utils.getAddress(CONSENSUS_PROXY);
  let votingAddress = ethers.utils.getAddress(VOTING_PROXY);
  let credentialsAddress = ethers.utils.getAddress(CREDENTIALS_ADDRESS);

  const ConsensusFactory = await ethers.getContractFactory("Consensus");
  const consensus = ConsensusFactory.attach(CONSENSUS_PROXY);
  const VotingFactory = await ethers.getContractFactory("Voting");
  const voting = VotingFactory.attach(VOTING_PROXY);

  console.log(`Consensus Contract: ${consensusAddress}`);
  console.log(`Voting Contract: ${votingAddress}`);
  console.log(`Credentials Address: ${credentialsAddress}`);

  const [validator] = await ethers.getSigners();
  console.log(`validator Address: ${validator.address}`);
  assert.equal(credentialsAddress, validator.address, "Account Mismatch");

  const action = "unJail";

  if (action === "unJail") {
    const tx = await consensus.unJail();
    await tx.wait();

    console.log(`Validator - unJail: ${validator.address}, tx: ${tx.hash}`);
  } else if (action === "vote") {
    const ballotId = 1;
    const tx = await voting.vote(ballotId, 1); //(id - the ballot id, choice - 1 is accept, 2 is reject)
    const receipt = await tx.wait();

    const voteEvent = receipt.events.find((event) => event.event === "Vote");
    const id = voteEvent.args[0];
    const choice = voteEvent.args[1];
    const voter = voteEvent.args[2];

    console.log(
      `Validator - voted: ${validator.address}, tx: ${tx.hash}, vote_id: ${id}, choice: ${choice}, voter: ${voter}`
    );
  } else if (action === "maintenance") {
    const tx = await consensus.maintenance();
    await tx.wait();

    console.log(
      `Validator - maintenance: ${validator.address}, tx: ${tx.hash}`
    );
  } else {
    console.log("Invalid action");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
