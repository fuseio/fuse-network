require("dotenv").config();
const fs = require("fs");
const path = require("path");
const hre = require("hardhat");
const ethers = hre.ethers;

/*
 * Rolls the staking rewards contract out through validator governance (Spark by default):
 *
 *   1. deploys the new ProxyStorage and BlockReward implementations and StakingRewards
 *   2. opens ballots to upgrade ProxyStorage and BlockReward to them
 *   3. once ProxyStorage is upgraded (only the new one knows the Staking contract type), opens a ballot
 *      to register StakingRewards
 *
 * A ballot opens for voting one cycle after the cycle it's created in, stays open for two cycles, and is
 * applied at the first cycle end after it closes, if validators voted for it. The signer has to be a validator
 * to open ballots, and votes for them while they are open (VOTE=false to skip).
 *
 * Every run reads the chain and the state file and does whatever step is due, so run it again as the
 * ballots progress, or set WATCH=true to keep it running until StakingRewards is live:
 *
 *   WATCH=true npx hardhat run scripts/7_deploy_staking.js --network spark
 *
 * Environment:
 *   BLOCK_REWARD_PROXY  BlockReward proxy to start from (defaults to Spark's); the other contracts are read from it
 *   STAKING_OPERATOR    address allowed to finalize cycle rewards (defaults to the signer)
 *   VOTE=false          don't vote for the ballots
 *   WATCH=true          keep running until done, checking every POLL_MINUTES (default 5)
 *   VERIFY=true         verify the new contracts on the block explorer
 */

const BLOCK_REWARD_PROXIES = {
  spark: "0xEa2151b6095CB76ECc57A57DE166728dd9b53Ed9",
};

// ProxyStorage.ContractTypes
const ContractType = { BlockReward: 2, ProxyStorage: 3, Staking: 5 };
// VotingBase.QuorumStates and VotingBase.ActionChoices
const QuorumState = { InProgress: 1, Accepted: 2, Rejected: 3 };
const ACCEPT = 1;

const START_AFTER_CYCLES = 1;
const DURATION_CYCLES = 2;
const DEPLOY_GAS_FALLBACK = 3000000;

function loadState(statePath) {
  if (!fs.existsSync(statePath)) return { ballots: {} };
  return JSON.parse(fs.readFileSync(statePath, "utf8"));
}

function saveState(statePath, state) {
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2) + "\n");
}

// Estimates gas passing the block tag explicitly. ethers leaves it out, which Blockscout's RPC rejects
async function gasLimitFor(signer, tx) {
  const request = ethers.providers.JsonRpcProvider.hexlifyTransaction({ ...tx, from: signer.address }, { from: true });
  const estimate = ethers.BigNumber.from(await ethers.provider.send("eth_estimateGas", [request, "latest"]));
  return estimate.mul(120).div(100);
}

// Sends a contract call with a gas limit from gasLimitFor and waits for it to be mined
async function send(contract, method, ...args) {
  const gasLimit = await gasLimitFor(contract.signer, await contract.populateTransaction[method](...args));
  const tx = await contract[method](...args, { gasLimit });
  const receipt = await tx.wait();
  return { tx, receipt };
}

async function deploy(name, args, signer, verify) {
  const factory = await ethers.getContractFactory(name, signer);
  let gasLimit;
  try {
    gasLimit = await gasLimitFor(signer, factory.getDeployTransaction(...args));
  } catch (error) {
    // Blockscout's RPC can't estimate contract creations; each of these deploys uses under 1.5M gas
    gasLimit = DEPLOY_GAS_FALLBACK;
    console.log(`Couldn't estimate gas to deploy ${name} (${error.message.split("\n")[0]}), using ${gasLimit}`);
  }
  const contract = await factory.deploy(...args, { gasLimit });
  await contract.deployed();
  console.log(`Deployed ${name} at ${contract.address} (tx ${contract.deployTransaction.hash})`);
  if (verify) {
    try {
      await hre.run("verify:verify", { address: contract.address, constructorArguments: args });
    } catch (error) {
      console.log(`Couldn't verify ${name}, verify it later: ${error.message}`);
    }
  }
  return contract.address;
}

function sameAddress(a, b) {
  return a.toLowerCase() === b.toLowerCase();
}

/**
 * Does the next due step of the rollout and reports where every part of it stands.
 * Returns { done: true } once both upgrades are applied and StakingRewards is registered.
 */
async function advance({ signer, statePath, blockRewardProxy, operator, vote = true, verify = false }) {
  const state = loadState(statePath);
  const save = () => saveState(statePath, state);

  if (state.blockRewardProxy && !sameAddress(state.blockRewardProxy, blockRewardProxy)) {
    throw new Error(`${statePath} is for BlockReward ${state.blockRewardProxy}, not ${blockRewardProxy}`);
  }
  state.blockRewardProxy = blockRewardProxy;

  const blockRewardProxyContract = await ethers.getContractAt("EternalStorageProxy", blockRewardProxy, signer);
  const proxyStorageAddress = await blockRewardProxyContract.getProxyStorage();
  const proxyStorageProxy = await ethers.getContractAt("EternalStorageProxy", proxyStorageAddress, signer);
  const proxyStorage = await ethers.getContractAt("ProxyStorage", proxyStorageAddress, signer);
  const voting = await ethers.getContractAt("Voting", await proxyStorage.getVoting(), signer);
  const consensus = await ethers.getContractAt("Consensus", await proxyStorage.getConsensus(), signer);
  const isValidator = await voting.isValidVotingKey(signer.address);

  // 1. Deploy, saving after each contract so a rerun never deploys twice
  if (!state.proxyStorageImpl) {
    state.proxyStorageImpl = await deploy("ProxyStorage", [], signer, verify);
    save();
  }
  if (!state.blockRewardImpl) {
    state.blockRewardImpl = await deploy("BlockReward", [], signer, verify);
    save();
  }
  if (!state.stakingRewards) {
    state.stakingRewards = await deploy("StakingRewards", [blockRewardProxy, operator], signer, verify);
    save();
  }
  save();

  const ballot = {
    async open(key, contractType, proposedValue, description) {
      if (!isValidator) {
        throw new Error(`${signer.address} isn't a validator, so it can't open the ${key} ballot`);
      }
      const { tx, receipt } = await send(voting, "newBallot", START_AFTER_CYCLES, DURATION_CYCLES, contractType, proposedValue, description);
      const created = receipt.events.find((event) => event.event === "BallotCreated");
      const id = created ? created.args[0].toNumber() : (await voting.getNextBallotId()).toNumber() - 1;
      state.ballots[key] = id;
      save();
      console.log(`Opened ballot ${id} (${description}), tx ${tx.hash}`);
      return id;
    },

    async voteIfOpen(id) {
      if (!vote || !(await voting.isActiveBallot(id))) return;
      if (await voting.hasAlreadyVoted(id, signer.address)) return;
      if (!isValidator) {
        console.log(`Not voting on ballot ${id}: only validators' votes count and ${signer.address} isn't one`);
        return;
      }
      const { tx } = await send(voting, "vote", id, ACCEPT);
      console.log(`Voted for ballot ${id}, tx ${tx.hash}`);
    },

    async describe(id) {
      const block = await ethers.provider.getBlockNumber();
      const start = (await voting.getStartBlock(id)).toNumber();
      const end = (await voting.getEndBlock(id)).toNumber();
      const voted = await voting.hasAlreadyVoted(id, signer.address);
      if (block <= start) return `ballot ${id} opens for voting after block ${start} (${start + 1 - block} blocks from now)`;
      if (block < end) return `ballot ${id} is open until block ${end} (${end - block} blocks from now), ${voted ? "voted for" : "not voted yet"}`;
      return `ballot ${id} closed at block ${end}, waiting for the cycle end to apply it`;
    },

    // Drives one ballot: opens it if needed, votes while it's open, and reports its progress
    async drive(key, contractType, proposedValue, description, isApplied) {
      if (await isApplied()) return { applied: true, status: "done" };

      let id = state.ballots[key];
      if (id !== undefined) {
        const quorumState = (await voting.getQuorumState(id)).toNumber();
        if (quorumState === QuorumState.Rejected) {
          const reason = (await voting.getBelowTurnOut(id)) ? "too few validators voted" : "validators voted against it";
          throw new Error(`Ballot ${id} (${description}) was rejected: ${reason}. Delete ballots.${key} from ${statePath} and run again to open a new one.`);
        }
        if (quorumState === QuorumState.Accepted) {
          throw new Error(`Ballot ${id} (${description}) was accepted but isn't applied on chain; check it manually`);
        }
      } else {
        id = await ballot.open(key, contractType, proposedValue, description);
      }

      await ballot.voteIfOpen(id);
      return { applied: false, status: await ballot.describe(id) };
    },
  };

  // 2. Upgrade ProxyStorage and BlockReward
  const proxyStorageStep = await ballot.drive(
    "proxyStorage",
    ContractType.ProxyStorage,
    state.proxyStorageImpl,
    "Upgrade ProxyStorage: add the Staking contract type",
    async () => sameAddress(await proxyStorageProxy.getImplementation(), state.proxyStorageImpl)
  );
  const blockRewardStep = await ballot.drive(
    "blockReward",
    ContractType.BlockReward,
    state.blockRewardImpl,
    "Upgrade BlockReward: record block rewards on the staking rewards contract",
    async () => sameAddress(await blockRewardProxyContract.getImplementation(), state.blockRewardImpl)
  );

  // 3. Register StakingRewards, which the old ProxyStorage can't do
  let stakingStep = { applied: false, status: "waits for the ProxyStorage upgrade" };
  if (proxyStorageStep.applied) {
    stakingStep = await ballot.drive(
      "staking",
      ContractType.Staking,
      state.stakingRewards,
      `Register StakingRewards at ${state.stakingRewards}`,
      async () => sameAddress(await proxyStorage.getStaking(), state.stakingRewards)
    );
  }

  console.log(`Block ${await ethers.provider.getBlockNumber()}, cycle ends at block ${await consensus.getCurrentCycleEndBlock()}`);
  console.log(`  ProxyStorage upgrade:      ${proxyStorageStep.status}`);
  console.log(`  BlockReward upgrade:       ${blockRewardStep.status}`);
  console.log(`  StakingRewards registered: ${stakingStep.status}`);

  const done = proxyStorageStep.applied && blockRewardStep.applied && stakingStep.applied;
  if (done) await checkRecording({ state, consensus, blockRewardProxy, signer });
  return { done, state };
}

// Once everything is live, confirm blocks are being recorded on StakingRewards
async function checkRecording({ state, consensus, blockRewardProxy, signer }) {
  const stakingRewards = await ethers.getContractAt("StakingRewards", state.stakingRewards, signer);
  const blockReward = await ethers.getContractAt("BlockReward", blockRewardProxy, signer);
  if (!sameAddress(await stakingRewards.blockReward(), blockRewardProxy)) {
    throw new Error(`StakingRewards ${state.stakingRewards} trusts ${await stakingRewards.blockReward()}, not BlockReward ${blockRewardProxy}`);
  }

  const cycle = await consensus.getCurrentCycleStartBlock();
  const weight = await stakingRewards.totalCycleWeights(cycle);
  const latest = await ethers.provider.getBlockNumber();
  const failures = await blockReward.queryFilter(blockReward.filters.StakingRecordFailed(), Math.max(latest - 100, 0), latest);

  console.log(`StakingRewards ${state.stakingRewards} is live`);
  console.log(`  cycle ${cycle} total weight so far: ${ethers.utils.formatEther(weight)}`);
  if (failures.length > 0) {
    console.log(`  WARNING: ${failures.length} StakingRecordFailed events in the last 100 blocks, first in tx ${failures[0].transactionHash}`);
  } else if (weight.isZero()) {
    console.log("  nothing recorded for this cycle yet; run again after a few blocks");
  }
}

async function main() {
  const network = hre.network.name;
  const blockRewardProxy = process.env.BLOCK_REWARD_PROXY || BLOCK_REWARD_PROXIES[network];
  if (!blockRewardProxy) throw new Error(`Set BLOCK_REWARD_PROXY: there's no default BlockReward for ${network}`);

  const [signer] = await ethers.getSigners();
  const options = {
    signer,
    statePath: path.join(__dirname, "..", "deployments", `staking-${network}.json`),
    blockRewardProxy: ethers.utils.getAddress(blockRewardProxy),
    operator: ethers.utils.getAddress(process.env.STAKING_OPERATOR || signer.address),
    vote: process.env.VOTE !== "false",
    verify: process.env.VERIFY === "true",
  };
  console.log(`Network ${network}, signer ${signer.address}, state in ${path.relative(process.cwd(), options.statePath)}`);

  const pollMs = Number(process.env.POLL_MINUTES || 5) * 60 * 1000;
  for (;;) {
    const { done } = await advance(options);
    if (done || process.env.WATCH !== "true") return;
    await new Promise((resolve) => setTimeout(resolve, pollMs));
  }
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = { advance };
