require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const { assert } = require("chai");

const { CONSENSUS_PROXY, CREDENTIALS_ADDRESS } = process.env;

async function main() {
  let consensusAddress = ethers.utils.getAddress(CONSENSUS_PROXY);
  let credentialsAddress = ethers.utils.getAddress(CREDENTIALS_ADDRESS);

  let stakeAmount = ethers.utils.parseUnits("100000", "ether");
  console.log(`Consensus Contract: ${consensusAddress}`);
  console.log(`Staking Amount: ${stakeAmount}`);
  console.log(`Staking Address: ${credentialsAddress}`);

  const [validator] = await ethers.getSigners();
  assert.equal(
    credentialsAddress,
    validator.address,
    "Staking Account Mismatch"
  );

  const ConsensusFactory = await ethers.getContractFactory("Consensus");
  const consensus = ConsensusFactory.attach(CONSENSUS_PROXY);

  const tx = await consensus.stake({ value: stakeAmount });
  await tx.wait();
  assert.equal(
    (await consensus.stakeAmount(validator.address)).toString(),
    stakeAmount.toString(),
    "Stake Amount Mismatch"
  );
  console.log(
    `Validator: ${validator.address}, Staked: ${stakeAmount}, tx: ${tx.hash}`
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
