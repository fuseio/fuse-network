require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;

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

  const ballotId = 1;

  const validators = await consensus.getValidators();
  
  let votingPowerAccept = 0
  let countAccept = 0

  let votingPowerReject = 0
  let countReject = 0

  let votingPowerNoVote = 0
  let countNoVote = 0
  // let totalAccept = ethers.BigNumber.from(0);
  for (validator of validators) {
    const choice = (await voting.getVoterChoice(ballotId, validator)).toString();
    const validatorStake = ethers.utils.formatEther((await consensus.stakeAmount(validator)));
    if (choice === '1') {
      console.log(`validator: ${validator}, voted ${choice === '1' ? "approve" : "reject"}. validator stake: ${validatorStake.toString()}`);
      votingPowerAccept += parseInt(validatorStake);
      countAccept++;
    } else if (choice === '2') {
      console.log(`validator: ${validator}, voted ${choice === '1' ? "approve" : "reject"}. validator stake: ${validatorStake.toString()}`);
      votingPowerReject += parseInt(validatorStake);
      countReject++;


    } else {
      console.log(`validator: ${validator}, did not voted yet. validator stake: ${validatorStake.toString()}`);
      votingPowerNoVote += parseInt(validatorStake);
      countNoVote++;
    }
  }

  console.log(`ACCEPT: ${countAccept} with voting power: ${votingPowerAccept}`);
  console.log(`REJECT: ${countReject} with voting power: ${votingPowerReject}`);
  console.log(`NO VOTE: ${countNoVote} with voting power: ${votingPowerNoVote}`);

  const totalStakeAmount = await consensus.totalStakeAmount();
  console.log(`Total stake amount: ${ethers.utils.formatEther(totalStakeAmount)}`);
  // const acceptedPercentage = votingPowerAccept / totalStakeAmount * 100;
  // console.log(`Accepted percentage: ${acceptedPercentage}%`);

  // for (uint256 j = 0; j < numOfValidators; j++) {
  //   uint256 choice = getVoterChoice(ballotId, validators[j]);
  //   if (choice == uint(ActionChoices.Accept)) {
  //     accepts = accepts.add(getStake(validators[j]));
  //   } else if (choice == uint256(ActionChoices.Reject)) {
  //     rejects = rejects.add(getStake(validators[j]));
  //   }
  // }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
