const fs = require('fs');
const solc = require('solc');
const Consensus = artifacts.require('./Consensus.sol');
const Web3 = require('web3')

const getWeb3Latest = () => {
 const web3Latest = new Web3(web3.currentProvider)
 return web3Latest
}

module.exports = function(deployer, network, accounts) {
  if (network !== 'test' && network !== 'ganache') {
    let consensusAddress = process.env.CONSENSUS_ADDRESS;
    let minStake = process.env.MIN_STAKE || 0;

    let validatorSet;

    deployer.then(async function() {
      if (!!process.env.DEPLOY_VALIDATOR_SET === true) {
        validatorSet = await Consensus.new(minStake);
        consensusAddress = validatorSet.address;
      } else {
        validatorSet = Consensus.at(consensusAddress);
      }

      const contracts = {
        'VALIDATOR_SET': consensusAddress
      };

      fs.writeFileSync('./contracts.json', JSON.stringify(contracts, null, 2));

      console.log(
        `
  Consensus.address ........................ ${consensusAddress}
        `
      )
    }).catch(function(error) {
      console.error(error);
    });
  }
};

async function compileContract(dir, contractName, contractCode) {
  const compiled = solc.compile({
    sources: {
      '': (contractCode || fs.readFileSync(`${dir}${contractName}.sol`).toString())
    }
  }, 1, function (path) {
    let content;
    try {
      content = fs.readFileSync(`${dir}${path}`);
    } catch (e) {
      if (e.code == 'ENOENT') {
        content = fs.readFileSync(`${dir}../${path}`);
      }
    }
    return {
      contents: content.toString()
    }
  });
  const compiledContract = compiled.contracts[`:${contractName}`];
  const abi = JSON.parse(compiledContract.interface);
  const bytecode = compiledContract.bytecode;
  return {abi, bytecode};
}

// CONSENSUS_ADDRESS=0x5f498450a2f199dc961b8e248fcc0c03098228ba MIN_STAKE=10000000000000000000000 ./node_modules/.bin/truffle migrate --reset --network fuse_pos
// DEPLOY_CONSENSUS=true CONSENSUS_ADDRESS=0x5f498450a2f199dc961b8e248fcc0c03098228ba MIN_STAKE=10000000000000000000000 ./node_modules/.bin/truffle migrate --reset --network fuse_pos
