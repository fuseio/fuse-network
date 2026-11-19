require("dotenv").config();
const path = require("path");
const hre = require("hardhat");
const { deployContracts, optionsFromEnv } = require("./7_deploy_staking");

/*
 * Deploys the staking rollout's contracts without opening any ballots: the new ProxyStorage and BlockReward
 * implementations, and StakingRewards (owned by the deployer). Any account with gas can run it, and it only
 * sends contract creations, so it works on the default Spark RPC.
 *
 *   npx hardhat run scripts/7_deploy_staking_contracts.js --network spark
 *
 * Addresses are saved to deployments/staking-<network>.json, the file scripts/7_deploy_staking.js reads, so
 * running that script afterwards with the validator key opens the ballots for these contracts instead of
 * deploying new ones. Rerunning this script skips contracts that are already deployed.
 *
 * Environment:
 *   BLOCK_REWARD_PROXY  BlockReward proxy StakingRewards trusts (defaults to Spark's)
 *   STAKING_OPERATOR    address allowed to finalize cycle rewards (defaults to the deployer)
 *   VERIFY=true         verify the contracts on the block explorer
 */

async function main() {
  const [signer] = await hre.ethers.getSigners();
  const options = optionsFromEnv(signer);
  console.log(`Network ${hre.network.name}, deployer ${signer.address}`);

  const state = await deployContracts(options);

  console.log("");
  console.log(`ProxyStorage implementation: ${state.proxyStorageImpl}`);
  console.log(`BlockReward implementation:  ${state.blockRewardImpl}`);
  console.log(`StakingRewards:              ${state.stakingRewards} (BlockReward ${state.blockRewardProxy}, operator ${options.operator})`);
  console.log(`Saved to ${path.relative(process.cwd(), options.statePath)}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
