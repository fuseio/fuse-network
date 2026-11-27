require("dotenv").config();
const fs = require("fs");
const path = require("path");
const hre = require("hardhat");
const ethers = hre.ethers;

/*
 * Rolls node version reporting out through validator governance (Spark by default):
 *
 *   1. deploys new Consensus and Voting implementations. If the live Consensus runs Spark's 720-block cycles,
 *      it deploys ConsensusSpark, so the upgrade keeps the cycle length. It stops before opening any ballot if
 *      the new Consensus would change the cycle length
 *   2. opens ballots to upgrade Consensus and Voting to them
 *   3. votes for both while they are open
 *
 * A ballot opens for voting one cycle after the cycle it's created in, stays open for two cycles, and is
 * applied at the first cycle end after it closes, if validators voted for it. On Spark (1 hour cycles) that's
 * about 3 to 4 hours. The signer has to be a validator to open ballots and to vote (VOTE=false to skip voting).
 *
 * Every run reads the chain and the state file and does whatever step is due, so run it again as the
 * ballots progress, or set WATCH=true to keep it running until both upgrades are live:
 *
 *   WATCH=true npx hardhat run scripts/7_deploy_version_reporting.js --network spark
 *
 * Environment:
 *   CONSENSUS_PROXY  Consensus proxy to upgrade (defaults to Spark's); Voting is read from it
 *   VOTE=false       don't vote for the ballots
 *   WATCH=true       keep running until done, checking every POLL_MINUTES (default 5)
 *   VERIFY=true      verify the new contracts on the block explorer
 */

const CONSENSUS_PROXIES = {
  spark: "0x8C682051D70301A0ca913Ce0A0e71539702E1122",
};

// ProxyStorage.ContractTypes
const ContractType = { Consensus: 1, Voting: 4 };
// VotingBase.QuorumStates and VotingBase.ActionChoices
const QuorumState = { InProgress: 1, Accepted: 2, Rejected: 3 };
const ACCEPT = 1;

const START_AFTER_CYCLES = 1;
const DURATION_CYCLES = 2;
const SPARK_CYCLE_DURATION_BLOCKS = 720;
const DEPLOY_GAS_FALLBACK = 6000000;

function loadState(statePath) {
  if (!fs.existsSync(statePath)) return { ballots: {} };
  return JSON.parse(fs.readFileSync(statePath, "utf8"));
}

function saveState(statePath, state) {
  fs.mkdirSync(path.dirname(statePath), { recursive: true });
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2) + "\n");
}

function sameAddress(a, b) {
  return a.toLowerCase() === b.toLowerCase();
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

async function deploy(name, signer, verify) {
  const factory = await ethers.getContractFactory(name, signer);
  let gasLimit;
  try {
    gasLimit = await gasLimitFor(signer, factory.getDeployTransaction());
  } catch (error) {
    // Blockscout's RPC can't estimate contract creations
    gasLimit = DEPLOY_GAS_FALLBACK;
    console.log(`Couldn't estimate gas to deploy ${name} (${error.message.split("\n")[0]}), using ${gasLimit}`);
  }
  const contract = await factory.deploy({ gasLimit });
  await contract.deployed();
  console.log(`Deployed ${name} at ${contract.address} (tx ${contract.deployTransaction.hash})`);
  if (verify) {
    try {
      await hre.run("verify:verify", { address: contract.address, constructorArguments: [] });
    } catch (error) {
      console.log(`Couldn't verify ${name}, verify it later: ${error.message}`);
    }
  }
  return contract.address;
}

// The live contracts, read from the Consensus proxy
async function liveContracts(consensusProxy, signer) {
  const consensusProxyContract = await ethers.getContractAt("EternalStorageProxy", consensusProxy, signer);
  const proxyStorage = await ethers.getContractAt("ProxyStorage", await consensusProxyContract.getProxyStorage(), signer);
  const votingProxy = await proxyStorage.getVoting();
  return {
    consensusProxyContract,
    votingProxyContract: await ethers.getContractAt("EternalStorageProxy", votingProxy, signer),
    consensus: await ethers.getContractAt("Consensus", consensusProxy, signer),
    voting: await ethers.getContractAt("Voting", votingProxy, signer),
  };
}

/**
 * Deploys the new Consensus and Voting implementations. Skips any already in the state file and saves each
 * address as soon as it's deployed, so a rerun never deploys twice. Throws if the new Consensus has a
 * different cycle length from the live one.
 */
async function deployContracts({ signer, statePath, consensusProxy, verify = false }) {
  const state = loadState(statePath);
  if (state.consensusProxy && !sameAddress(state.consensusProxy, consensusProxy)) {
    throw new Error(`${statePath} is for Consensus ${state.consensusProxy}, not ${consensusProxy}`);
  }
  state.consensusProxy = consensusProxy;
  state.ballots = state.ballots || {};
  const save = () => saveState(statePath, state);

  const { consensus } = await liveContracts(consensusProxy, signer);
  const liveCycleBlocks = (await consensus.getCycleDurationBlocks()).toNumber();
  const consensusContract = liveCycleBlocks === SPARK_CYCLE_DURATION_BLOCKS ? "ConsensusSpark" : "Consensus";
  save();

  if (!state.consensusImpl) {
    state.consensusContract = consensusContract;
    state.consensusImpl = await deploy(consensusContract, signer, verify);
    save();
  }
  if (!state.votingImpl) {
    state.votingImpl = await deploy("Voting", signer, verify);
    save();
  }

  // getCycleDurationBlocks is pure, so the implementation answers it directly
  const newConsensus = await ethers.getContractAt("Consensus", state.consensusImpl, signer);
  const newCycleBlocks = (await newConsensus.getCycleDurationBlocks()).toNumber();
  if (newCycleBlocks !== liveCycleBlocks) {
    throw new Error(
      `The new Consensus ${state.consensusImpl} runs ${newCycleBlocks}-block cycles but the live one runs ${liveCycleBlocks}. ` +
        `Upgrading would change the cycle length, so no ballot was opened.`
    );
  }
  return state;
}

/**
 * Does the next due step of the rollout and reports where it stands.
 * Returns { done: true } once Consensus and Voting both run the new implementations.
 */
async function advance({ signer, statePath, consensusProxy, vote = true, verify = false }) {
  // 1. Deploy whatever isn't deployed yet
  const state = await deployContracts({ signer, statePath, consensusProxy, verify });
  const save = () => saveState(statePath, state);
  const { consensusProxyContract, votingProxyContract, consensus, voting } = await liveContracts(consensusProxy, signer);
  const isValidator = await voting.isValidVotingKey(signer.address);

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

  // 2. and 3. Upgrade Consensus and Voting
  const consensusStep = await ballot.drive(
    "consensus",
    ContractType.Consensus,
    state.consensusImpl,
    `Upgrade Consensus: node version reporting (${state.consensusContract})`,
    async () => sameAddress(await consensusProxyContract.getImplementation(), state.consensusImpl)
  );
  const votingStep = await ballot.drive(
    "voting",
    ContractType.Voting,
    state.votingImpl,
    "Upgrade Voting: node version ballots",
    async () => sameAddress(await votingProxyContract.getImplementation(), state.votingImpl)
  );

  console.log(`Block ${await ethers.provider.getBlockNumber()}, cycle ends at block ${await consensus.getCurrentCycleEndBlock()}`);
  console.log(`  Consensus upgrade: ${consensusStep.status}`);
  console.log(`  Voting upgrade:    ${votingStep.status}`);

  const done = consensusStep.applied && votingStep.applied;
  if (done) await checkLive({ consensus, voting });
  return { done, state };
}

// Once both upgrades are live, confirm version reporting answers and the cycle length is what it was
async function checkLive({ consensus, voting }) {
  const validators = await consensus.getValidators();
  console.log("Version reporting is live");
  console.log(`  cycle length: ${await consensus.getCycleDurationBlocks()} blocks`);
  console.log(`  required node version: ${await consensus.getRequiredNodeVersion()} (0 = none scheduled)`);
  for (const validator of validators) {
    console.log(`  ${validator} reported version ${await consensus.getNodeVersion(validator)} (0 = not reported yet)`);
  }
  console.log(`  next ballot id: ${await voting.getNextBallotId()}`);
}

// Options for this network and signer from the environment variables listed at the top
function optionsFromEnv(signer) {
  const network = hre.network.name;
  const consensusProxy = process.env.CONSENSUS_PROXY || CONSENSUS_PROXIES[network];
  if (!consensusProxy) throw new Error(`Set CONSENSUS_PROXY: there's no default Consensus for ${network}`);

  return {
    signer,
    statePath: path.join(__dirname, "..", "deployments", `version-reporting-${network}.json`),
    consensusProxy: ethers.utils.getAddress(consensusProxy),
    vote: process.env.VOTE !== "false",
    verify: process.env.VERIFY === "true",
  };
}

async function main() {
  const [signer] = await ethers.getSigners();
  if (!signer) throw new Error("No signer: set WALLET_PROVIDER_METHOD and the matching key in .env");
  const options = optionsFromEnv(signer);
  console.log(`Network ${hre.network.name}, signer ${signer.address}, state in ${path.relative(process.cwd(), options.statePath)}`);

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

module.exports = { advance, deployContracts, optionsFromEnv };
