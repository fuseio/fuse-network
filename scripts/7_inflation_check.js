require("dotenv").config();
const hre = require("hardhat");
const ethers = hre.ethers;

const { CONSENSUS_PROXY, BLOCK_REWARD_PROXY } = process.env;

function blocksToDays(blocks) {
  const secondsInDay = 86400;
  const secondsInBlock = 5;
  return blocks * secondsInBlock / secondsInDay;
}

function blocksToHours(blocks) {
  const secondsInHour = 3600;
  const secondsInBlock = 5;
  return blocks * secondsInBlock / secondsInHour;
}


async function main() {
  let consensusAddress = ethers.utils.getAddress(CONSENSUS_PROXY);
  let blockRewardAddress = ethers.utils.getAddress(BLOCK_REWARD_PROXY);
  console.log('---------------------GENERAL---------------------');
  const blockNumber = await ethers.provider.getBlockNumber();
  const currentDate = new Date();
  console.log(`Current UTC Date: ${currentDate.toUTCString()}`);
  console.log(`Current Linux Epoch Time: ${Math.floor(currentDate.getTime() / 1000)}`);


  console.log(`Consensus Contract: ${consensusAddress}`);
  console.log(`BlockReward Contract: ${blockRewardAddress}`);

  const ConsensusFactory = await ethers.getContractFactory("Consensus");
  const consensus = ConsensusFactory.attach(CONSENSUS_PROXY);

  const BlockRewardFactory = await ethers.getContractFactory("BlockReward");
  const blockReward = BlockRewardFactory.attach(BLOCK_REWARD_PROXY);
  let proxyStorageAddress = await blockReward.getProxyStorage();
  console.log(`ProxyStorage Address: ${proxyStorageAddress}`);
  const ProxyStorageFactory = await ethers.getContractFactory("ProxyStorage");
  const proxyStorage = ProxyStorageFactory.attach(proxyStorageAddress);
  ;
  console.log(`Voting Address: ${await proxyStorage.getVoting()}`);
  // const blockNumber = await hre.ethers.provider.getBlockNumber();
  // console.log("Current block number: " + blockNumber);

  // console.log(ethers.provider)
  // console.log(hre.network.config.chainId)
  // console.log(await ethers.ge(hre.network.config.chainId).getNetwork())

  const blocksPerYear = await  blockReward.getBlocksPerYear() 
  console.log(`Current Blocknumber: ${blockNumber}`);
  console.log(`Current Inflation: ${ await blockReward.getInflation() }`);
  console.log(`Current reward: ${ await  blockReward.getBlockRewardAmount() }`);

  console.log('---------------------CYCLE INFO---------------------')
  const cycleStartBlock = await consensus.getCurrentCycleStartBlock();
  const getCurrentCycleEndBlock = await consensus.getCurrentCycleEndBlock();
  console.log(`Cycle starts: ${ cycleStartBlock }`);
  console.log(`Cycle ends: ${ getCurrentCycleEndBlock }`);
  console.log(`Cycle size: ${ getCurrentCycleEndBlock - cycleStartBlock }`)
  const blocksToNextCycle = getCurrentCycleEndBlock - blockNumber;
  console.log(`Nexr Cycle start in : ${ blocksToNextCycle } blocks, days: ${ blocksToDays(blocksToNextCycle) }, hours: ${ blocksToHours(blocksToNextCycle) }`);
  // console.log(`Current cycle: ${ await blockReward.getCurrentCycle() }`);

  console.log('---------------------YEAR INFO--------------------');
  console.log(`Current year: ${ Math.floor(blockNumber / blocksPerYear) }`);
  console.log(`Blocks per year: ${ blocksPerYear }`);
  const blocksToNextYear = blocksPerYear - (blockNumber % blocksPerYear);  
  console.log(`next year starts in: ${ blocksToNextYear } blocks, days: ${ blocksToDays(blocksToNextYear) }`);
  console.log(`next year end block: ${ blockNumber + blocksToNextYear } blocks`);

  // console.log(`getInflation ${ await blockReward.getInflation()}`)

  await inflationCheck(blockReward);
  // (getTotalSupply().mul(getInflation().mul(DECIMALS).div(10000))).div(getBlocksPerYear()).div(DECIMALS);
  // const getCurrentCycleEndBlockBack = await consensus.getCurrentCycleEndBlock({ blockTag: 17142050 });
  // console.log(`getCurrentCycleEndBlockBack: ${ getCurrentCycleEndBlockBack }`);
  // console.log(`Current Inflation: ${ await blockReward.getInflation( { blockTag: 17142050 }) }`);
  // const forkBlock = 17142050;
  // console.log(`getInflation on block ${17109807} ${ await blockReward.getInflation({ blockTag: 17109807 })}`)
  // console.log(`getInflation on block ${17142050} ${ await blockReward.getInflation({ blockTag: forkBlock - 100 })}`)
  // console.log(`getInflation on block ${17142664} ${ await blockReward.getInflation({ blockTag: 17142664 })}`);

  
}

async function inflationCheck(blockReward) {
  const blockTag = 17470080
  const totalSupply = await blockReward.getTotalSupply({ blockTag });
  const inflation = await blockReward.getInflation({ blockTag });
  const blocksPerYear = await blockReward.getBlocksPerYear({ blockTag });

  console.log(`getTotalSupply ${ totalSupply }`)
  console.log(`getInflation ${ inflation }`)
  console.log(`getBlocksPerYear ${ blocksPerYear }`)

  console.log(`totalSupply * inflation / 10000 / blocksPerYear / 1e18: ${ 382884469 * 300 / 10000 / 6307200 }`)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
