require('dotenv').config()
const HDWalletProvider = require('truffle-hdwallet-provider')
const fs = require('fs')
const EthWallet = require('ethereumjs-wallet')

const {
  RPC,
  WALLET_PROVIDER_METHOD,
  CREDENTIALS_KEYSTORE,
  CREDENTIALS_PASSWORD,
  MNEMONIC
} = process.env

let walletProvider
if (WALLET_PROVIDER_METHOD === 'keystore') {
  const keystore = fs.readFileSync(CREDENTIALS_KEYSTORE).toString()
  const password = fs.readFileSync(CREDENTIALS_PASSWORD).toString().trim()
  const wallet = EthWallet.fromV3(keystore, password)
  const pkey = wallet.getPrivateKeyString()
  walletProvider = new HDWalletProvider(pkey, RPC)
} else if (WALLET_PROVIDER_METHOD === 'mnemonic') {
  walletProvider = new HDWalletProvider(MNEMONIC, RPC)
}

module.exports = {
  networks: {
    ganache: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gas: 10000000
    },
    test: {
      host: 'localhost',
      port: 8545,
      network_id: '*',
      gas: 10000000
    },
    fuse: {
      provider: walletProvider,
      network_id: 123,
      // gas: 10000000,
      gasPrice: 1000000000 // 1 gwei
    },
    local: {
      provider: walletProvider,
      network_id: 999,
      // gas: 10000000,
      gasPrice: 1000000000 // 1 gwei
    }
  },
  compilers: {
    solc: {
      version: '0.4.24',
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions: {
      currency: 'USD',
      gasPrice: 1
    }
  }
}
