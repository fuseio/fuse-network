require("@nomiclabs/hardhat-truffle5");
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 122,
      accounts: {
        mnemonic: "test test test test test test test test test test test fuse",
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
        accountsBalance: "1000000000000000000000000",
      },
    },
    fuse: {
      url: "https://rpc.fuse.io",
      chainId: 122,
    },
    spark: {
      url: "https://rpc.fusespark.io",
      chainId: 123,
    },
  },
  solidity: {
    version: "0.4.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "constantinople",
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 40000,
  },
};
