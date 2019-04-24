require('dotenv').config()
const HDWalletProvider = require('truffle-hdwallet-provider')
const fs = require('fs')
const EthWallet = require('ethereumjs-wallet')
const WalletProvider = require('truffle-wallet-provider')

let walletProvider
if (process.env.WALLET_PROVIDER_METHOD === 'keystore') {
  const credentialsPath = ('./setup/nodes/validator.0/credentials/')
  const wallet = EthWallet.fromV3(
    fs.readFileSync(`${credentialsPath}/keystore`).toString(),
    fs.readFileSync(`${credentialsPath}/pass`).toString()
  )
  walletProvider = new WalletProvider(wallet, 'http://127.0.0.1:8545')
  console.log(`Wallet address ${wallet.getAddressString()}`)
} else if (process.env.WALLET_PROVIDER_METHOD === 'mnemonic') {
  walletProvider = new HDWalletProvider(process.env.MNEMONIC, 'http://127.0.0.1:8545')
  console.log(`Wallet address ${walletProvider.addresses[0]}`)
} else {
  console.log(`No wallet provider found...`)
}

module.exports = {
  networks: {
    ganache: {
      host: 'localhost',
      port: 8545,
      network_id: '*', // eslint-disable-line camelcase
      gasPrice: 1000000000
    },
    fuse_pos: {
      provider: walletProvider,
      network_id: '*',
      gasPrice: 1000000000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  mocha: {
    reporter: 'eth-gas-reporter',
    reporterOptions : {
      currency: 'USD',
      gasPrice: 1
    }
  }
}
