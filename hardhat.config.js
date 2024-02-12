require("solidity-coverage");
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

const {
  WALLET_PROVIDER_METHOD,
  CREDENTIALS_ADDRESS,
  CREDENTIALS_KEYSTORE,
  CREDENTIALS_PASSWORD,
  MNEMONIC,
  PRIVATE_KEY,
} = process.env;

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
      accounts: getSigners(),
    },
    spark: {
      url: "https://rpc.fusespark.io",
      chainId: 123,
      accounts: getSigners(),
    },
    devnet: {
      url: "http://34.38.118.140:8545",
      chainId: 123,
      accounts: getSigners(),
      allowUnlimitedContractSize: true,
    },
  },
  solidity: {
    version: "0.4.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
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
  etherscan: {
    apiKey: {
      spark: "abc",
      fuse: "abc",
    },
    customChains: [
      {
        network: "spark",
        chainId: 123,
        urls: {
          apiURL: "https://explorer.fusespark.io/api/",
          browserURL: "https://explorer.fusespark.io",
        },
      },
      {
        network: "fuse",
        chainId: 122,
        urls: {
          apiURL: "https://explorer.fuse.io/api/",
          browserURL: "https://explorer.fuse.io",
        },
      },
    ],
  },
};
function getSigners() {
  let signers = [];
  if (WALLET_PROVIDER_METHOD === "keystore") {
    const fs = require("fs");
    const os = require("os");
    const path = require("path");
    const keythereum = require("keythereum");

    const keystore_dir = path.join(os.homedir(), CREDENTIALS_KEYSTORE);
    const password_dir = path.join(os.homedir(), CREDENTIALS_PASSWORD);
    const password = fs.readFileSync(password_dir, "utf8");
    const keyobj = keythereum.importFromFile(CREDENTIALS_ADDRESS, keystore_dir);
    const privateKey = keythereum.recover(password, keyobj);

    signers.push(privateKey.toString("hex"));
  } else if (WALLET_PROVIDER_METHOD === "mnemonic") {
    const wallet = Wallet.fromMnemonic(MNEMONIC);
    const privateKey = wallet.getPrivateKeyString();
    signers.push(privateKey);
  } else if (WALLET_PROVIDER_METHOD === "privateKey") {
    signers.push(PRIVATE_KEY);
  }
  return signers;
}
