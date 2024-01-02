require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;
const { assert } = require("chai");

const { CREDENTIALS_ADDRESS } = process.env;

async function main() {
  let credentialsAddress = ethers.utils.getAddress(CREDENTIALS_ADDRESS);
  const recipientAddress = "0x79610a5a9da29b6e9ee5e6e524d6e837653d0021";

  const transferAmount = ethers.utils.parseUnits("110000", "ether");
  console.log(`Transfer Amount: ${transferAmount}`);

  const [owner] = await ethers.getSigners();
  assert.equal(credentialsAddress, owner.address, "Staking Account Mismatch");

  // send from signer to 0x00001
  const tx = await owner.sendTransaction({
    to: recipientAddress,
    value: transferAmount,
  });
  await tx.wait();

  const recipientBalance = await ethers.provider.getBalance(recipientAddress);

  assert.equal(
    recipientBalance.toString(),
    transferAmount.toString(),
    "Owner Balance Mismatch"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
