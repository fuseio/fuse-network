# fuse-pos-network
[Solidity](https://solidity.readthedocs.io/en/v0.4.24/) contracts for Fuse PoS Network based on [Parity Ethereum](https://wiki.parity.io/Parity-Ethereum)

## Contracts
* [Consensus](https://github.com/ColuLocalNetwork/fuse-pos-network/contracts/Consensus.sol) - non-reporting Validator Set contract as described [here](https://wiki.parity.io/Validator-Set.html)

## Prerequisites

#### Clone the repository
`git clone https://github.com/ColuLocalNetwork/fuse-pos-network.git ~/Dev/fuse-pos-network`

#### Install dependencies
`npm install`

#### Run unit tests
`npm test`

#### Install [Parity](https://wiki.parity.io/Setup)
Developed and tested using `v2.4.5` installed on MacOS (with Homebrew)

## Setup a local network
Based on [Parity's Validator Set Tutorial](https://wiki.parity.io/Validator-Set-Tutorial-Overview.html)

### Workflow

1. `node.0` will be the only authority allowed to seal blocks at the genesis of the blockchain.
2. `alice`, who holds all initial coins of the network (100 million) will deploy a `Consensus` contract.
3. `alice` will distribute some coins to `node.0` and to `node.1`
3. `node.0` will add itself as validator
4. `node.0` will plan a fork to switch from a fixed list of validators to the `Consensus` contract.
5. `node.1` will add itself as validator as well after the hard-fork

####  Create directory to persist blockchain files, keys, etc.
* `mkdir -p ~/Dev/io.parity.ethereum/`

#### Setup the first node of the network called **`node.0`**
* Create directory for `node.0`'s data
	* `mkdir ~/Dev/io.parity.ethereum/node.0`
	* `cp ~/Dev/fuse-pos-network/parity/config.toml.example ~/Dev/io.parity.ethereum/node.0/config.toml`
	* `cp ~/Dev/fuse-pos-network/parity/spec.json.example ~/Dev/io.parity.ethereum/node.0/spec.json`
* Create account and password file for `node.0`'s account
	* `cd ~/Dev/io.parity.ethereum/node.0/`
	* `parity --config config.toml account new`
	* `echo "<THE_PASSWORD>" > pwd`
* Edit `config.toml`
	*  `[account]` section
		*  `passowrd = ["pwd"]`
	*  `[mining]` section
		*  `engine_signer=<ACCOUNT_ADDRESS_CREATED>`
* Edit `spec.json`
	* `"validators": {"multi": {"0": {"list": ["ACCOUNT_ADDRESS_CREATED"]}}}`
* Launch `node.0` to make sure everything is valid
	* `parity --config config.toml`
	* You should see a similar line every 5 seconds: `Imported #1 0x1204…4d39 (0 txs, 0.00 Mgas, 1 ms, 0.57 KiB)`
	* Copy the public node address `enode://752963538fbf4fd29bef9845088763c93bfc9663bf2b4a5dd38408c3c55e0125fddea2d8c6af8a9182cf56d4e5114cf064ea89f225eb07abc026ac42a4404abb@40.0.0.67:30300` and save it to `enode`

#### Setup the second node of the network called  **`node.1`**
Repeat the previous process as before (remember to replace all `node.0` occurrences with `node.1`) but with the same `spec.json` as used by `node.0`, only change in `config.toml`:

* `[network]` section
	* `port = 30301`

#### Setup the third node for deploying the Consensus contract called **`alice`**
Repeat the previous process as before (remember to replace all `node.0` occurrences with `alice`) but with some changes:

* `spec.json`
	* `"accounts": {"ACCOUNT_ADDRESS_CREATED": {"balance": "100000000000000000000000000"}}`
* `config.toml`
	* `[network]` section
		* `port = 30302`
	* `[rpc]` section
		* `cors = ["all"]`
		* `port = 8545`
		* `interface = "all"`
		* `hosts = ["all"]`
		* `apis = ["web3", "eth", "net", "parity", "traces", "rpc", "secretstore"]`
	* `[websockets]` section
		* `disable = false`
		* `port = 8546`
		* `interface = "all"`
		* `origins = ["all"]`
		* `hosts = ["all"]`
		* `apis = ["web3", "eth", "net", "parity", "traces", "rpc", "secretstore"]`
	* `[account]` section
		* `unlock = ["<ACCOUNT_ADDRESS_CREATED>"]`
		* `passowrd = ["pwd"]`
	* `[mining]` section
		* Delete entirely

#### Add bootnodes to all configuration files
* Edit `config.toml` of `node.0`, `node.1` and `alice`:
	* `[network]` section

```code
		bootnodes = [
			"enode://<NODE_0_ENODE>",
			"enode://<NODE_1_ENODE>",
			"enode://<ALICE_ENODE>"
		]
```

#### Deploy Consensus contract by **`alice`**
* `cd ~/Dev/fuse-pos-network/`
* `cp .env.example .env`
* Edit `.env`
	* `WALLET_PROVIDER_METHOD=keystore`
	* `CREDENTIALS_KEYSTORE=~/Dev/io.parity.ethereum/alice/data/keys/FuseNetworkPOS/UTC--2019-04-30T11-43-32Z--a72d124a-5c05-c97c-e345-65c030649352`
	* `CREDENTIALS_PASSWORD=/Users/liorrabin/Dev/io.parity.ethereum/alice/pwd`
	* `DEPLOY_CONSENSUS=true`
	* `CONSENSUS_ADDRESS=0x5f498450a2f199dc961b8e248fcc0c03098228ba`
	* `MIN_STAKE=10000000000000000000000`
* `./node_modules/.bin/truffle migrate --reset --network fuse_pos`
* Using your favorite Ethereum wallet send some coins from `alice`'s account to `node.0` and to `node.1` so they have enough to stake and become network validators
* Add `node.0` and `node.1` as validators by sending more than the minimum stake defined in the Consensus contract to the deployed contract address
* Update `spec.json` of all nodes to perform a hard-fork in a future block
	* `"validators": {"multi": {"250": {"contract": ["DEPLOYED_CONTRACT_ADDRESS"]}}}`
* Wait for the hard-fork to occur and from that point on you can see that the mining is split between `node.0` and `node.1`
