# Fuse Network

- [Fuse Network](#fuse-network)
  - [General](#general)
    - [Clone Repository](#clone-repository)
    - [Install Dependencies](#install-dependencies)
    - [Run Unit Tests](#run-unit-tests)
  - [Contracts](#contracts)
    - [Compile](#compile)
    - [ABIs](#abis)
    - [Flatten](#flatten)
    - [Deploy](#deploy)
  - [Run Local Node](#run-local-node)
    - [Pre-Requisites](#pre-requisites)
    - [Hardware](#hardware)
    - [Networking](#networking)
    - [Using Quickstart](#using-quickstart)
      - [OE](#oe)
      - [Nethermind](#nethermind)
    - [Using Docker](#using-docker)
      - [Usage](#usage)
      - [Examples](#examples)
        - [Bootnode](#bootnode)
        - [Node](#node)
        - [Validator](#validator)
        - [Create New Account](#create-new-account)
        - [Archival node](#archival-node)
  - [Building containers](#building-containers)

## General

### Clone Repository

```
$ git clone https://github.com/fuseio/fuse-network.git ~/Dev/fuse-network
```

### Install Dependencies

```
$ yarn install
```

### Run Unit Tests

```
$ yarn test
```

## Contracts

### Compile

```
$ yarn compile
```

### Flatten

```
$ yarn flatten
```

### Deploy

Make sure `NETWORK_NAME` is defined in [`hardhat.config`](https://github.com/fuseio/fuse-network/blob/master/hardhat.config.js)

Make sure you've created an `.env` using the template [`env.example`](https://github.com/fuseio/fuse-network/blob/master/.env.example)

Run:

```
npx hardhat run scripts/<SCRIPT_NAME> --network <NETWORK_NAME>
```

## Run Local Node

Please make sure you have access to a continuously running machine, if you like to participate as a network validator.

### Pre-Requisites

A complete [Docker](https://docs.docker.com) environment is needed to be installed on your system, as well as [Docker-Compose](https://docs.docker.com/compose/)

Make sure that your user is added to the `docker` user-group on _Unix_ systems, if you can't access root permissions to run containers.

### Hardware

> Note:
>
> - Specified for [AWS](https://console.aws.amazon.com), but similar on other providers as well
> - Depending on your node purpose (shared RPC endpoint with hight load) system requirements could be different
> - `-` in each column means that role has the same parameters like previous

| Node role          | Bootnode                                                  | Node | Validator | Archival                                                 |
| ------------------ | --------------------------------------------------------- | ---- | --------- | -------------------------------------------------------- |
| Operating system   | Ubuntu (18.04 and higher) or any other Linux distribution | -    | -         | -                                                        |
| Runtime            | On - Premise, Docker, Kubernetes                          | -    | -         | -                                                        |
| Compute            | Minimal: 2vCPU, 8GB RAM; Recommended: 4vCPU, 16GB RAM     | -    | -         |                                                          |
| Disk type and size | 150GB SSD; Read/Write IOPS - 5000, Throughput - 125 MB/s  | -    | -         | 2TB SSD; Read / Write IOPS - 5000, Throughput - 125 MB/s |

### Networking

| Name | Port  | Protocol | Action       | Description                                                   | Notes                          |
| ---- | ----- | -------- | ------------ | ------------------------------------------------------------- | ------------------------------ |
| P2P  | 30303 | TCP      | Allow        | Port used for communication with the network peers            | Should be openned for everyone |
| P2P  | 30303 | UDP      | Allow        | -                                                             | -                              |
| RPC  | 8545  | TCP      | Allow / Deny | Port used for communication with the node with HTTP JSON RPC  | Please, see notes below        |
| WS   | 8546  | TCP      | Allow / Deny | Port used for communication with the node with HTTP WebSocket | Please, see notes below        |

> Note:
>
> - Outbound traffic should be oppened for all IP addresses
> - For Bootnode node role not necessarry to open RPC and WS ports, only P2P are required; for Validator node role WS and RPC ports should be openned on `localhost` and granted restricted access through IP whitelists

### Using Quickstart

#### OE

To make starting a node for the FuseNetwork as quick as possible, the _quickstart_ script can be used.

1. Download the script.

2. Download one of the example `.env` files located at the [examples folder](https://github.com/fuseio/fuse-network/tree/master/scripts/examples).

3. Modify the `.env` file according to the role/type of node you're running.

4. Start the script.

The script will make sure you have everything that is necessary, create a new account for you (if needed) and start the relevant containers (based on the role/type of node) with all requested arguments.

The script can be called multiple times without problems, so it checks what is already there and will at least update all service processes.

```sh
$ wget -O quickstart.sh https://raw.githubusercontent.com/fuseio/fuse-network/master/scripts/quickstart.sh
$ chmod 777 quickstart.sh
$ wget -O .env https://raw.githubusercontent.com/fuseio/fuse-network/master/scripts/examples/.env.<ROLE>.example
$ ./quickstart.sh
```

Follow the instructions emitted by the script.

#### Nethermind

Since **08.2022** Fuse is moving from OE client to [Nethermind](https://nethermind.io). To bootstrap your own Fuse (Spark) node on Nethermind client you could use [quickstart.sh](./nethermind/quickstart.sh) script.

```bash
# Download
wget -O quickstart.sh https://raw.githubusercontent.com/fuseio/fuse-network/master/nethermind/quickstart.sh

# Gain needed permissions
chmod 755 quickstart.sh

# Run
./quickstart.sh -r [node_role] -n [network_name] -k [node_key]
```

Full example provided [here](./nethermind/README.md).

---

### Using Docker

The following instructions explain how to start a local node with the _Docker_ image.

In fact it uses a pre-configured [Parity Ethereum](https://www.parity.io/) client, combined with a set-up wrapper, to make connecting as easy as possible.

The image is prepared to be used as node, validator or explorer node.

#### Usage

To run the parity client for the FuseNetwork you first have to pull the image from
[DockerHub](https://hub.docker.com/r/fusenet/node).

It does not matter in which directory your are working this step, cause it will be added to _Docker_'s very own database.

Afterwards calling the help should give a first basic overview how to use.

```
$ docker pull fusenet/node
$ docker run fusenet/node --help

 	# NAME
#   Parity Wrapper
#
# SYNOPSIS
#   parity_wrapper.sh [-r] [role] [-a] [address] [-p] [arguments]
#
# DESCRIPTION
#   A wrapper for the actual Parity client to make the Docker image easy usable by preparing the Parity client for
#   a set of predefined list of roles the client can take without have to write lines of arguments on run Docker.
#
# OPTIONS
#   -r [--role]         Role the Parity client should use.
#                       Depending on the chosen role Parity gets prepared for that role.
#                       Selecting a specific role can require further arguments.
#                       Checkout ROLES for further information.
#
#   -a [--address]      The Ethereum address that parity should use.
#                       Depending on the chosen role, the address gets inserted at the right place of the configuration, so Parity is aware of it.
#                       Gets ignored if not necessary for the chosen role.
#
#   -p [--parity-args]  Additional arguments that should be forwarded to the Parity client.
#                       Make sure this is the last argument, cause everything after is forwarded to Parity.
#
# ROLES
#   The list of available roles is:
#
#   bootnode
#     - No mining.
#     - RPC ports open.
#     - Does not require the address argument.
#     - Does not need the password file and the key-set. (see FILES)
#   node
#     - No mining.
#     - RPC ports open.
#     - Does not require the address argument.
#     - Does not need the password file and the key-set. (see FILES)
#
#   validator
#     - Connect as authority to the network for validating blocks.
#     - Miner.
#     - RPC ports open.
#     - Requires the address argument.
#     - Needs the password file and the key-set. (see FILES)
#
#   explorer
#     - No mining.
#     - RPC ports open.
#     - Does not require the address argument.
#     - Does not need the password file and the key-set. (see FILES)
#     - Some of Parity's settings are configured specifically for the use of blockscout explorer.
#
# FILES
#   The configuration folder for Parity takes place at /home/parity/.local/share/io.parity.ethereum.
#   Alternately the shorthand symbolic link at /config can be used.
#   Parity's database is at /home/parity/.local/share/io.parity.ethereum/chains or available trough /data as well.
#   To provide custom files in addition bind a volume through Docker to the sub-folder called 'custom'.
#   The password file is expected to be placed in the custom configuration folder names 'pass.pwd'.
#   The key-set is expected to to be placed in the custom configuration folder under 'keys/FuseNetwork/'
#   Besides from using the pre-defined locations, it is possible to define them manually thought the parity arguments. Checkout their documentation to do so.
```

#### Examples

Besides the original help, the following sections provide some example instructions how to get started for the different roles.

##### Bootnode

```
## Start parity container with all necessary arguments.
$ docker run \
    --detach \
    --name fusenet \
    --volume $(pwd)/fusenet/database:/data \
    --volume $(pwd)/fusenet/config:/config/custom \
    -p 30303:30300/tcp \
    -p 30303:30300/udp \
    -p 8545:8545 \
    -p 8546:8546 \
    --restart=always \
    fusenet/node \
    --role node \
    --parity-args --no-warp --node-key $NODE_KEY --bootnodes=$BOOTNODES
```

##### Node

```
## Start parity container with all necessary arguments.
$ docker run \
    --detach \
    --name fusenet \
    --volume $(pwd)/fusenet/database:/data \
    --volume $(pwd)/fusenet/config:/config/custom \
    -p 30303:30300/tcp \
    -p 30303:30300/udp \
    -p 8545:8545 \
    -p 8546:8546 \
    --restart=always \
    fusenet/node \
    --role node \
    --parity-args --no-warp --node-key $NODE_KEY
```

##### Validator

The validator should be connected with an account to sign transactions and interact with the blockchain, the help output states that the accounts key-pair, address and the related password is necessary to provide.

To make all files accessible to the _Docker_ container needs a binded volume.

Therefore create a new folder to do so.

The following instructions expect the folder `config` inside the current working directory. Adjust them if you prefer a different location.

Inside a directory for the keys with another sub-directory for the FuseNetwork chain is used by _Parity_.

Your key-file has to be placed there.

Afterwards the key's password has to be stored into a file directly inside the `config` folder.

To make use of the default configurations without adjustment, the file has to be called `pass.pwd`.

If you have no account already or want to create a new one for this purpose checkout [this section](#create-new-account).

Using so the previous paragraph as well as the first 2-3 instructions can be ignored.

Anyways the password used there has to be stored as shown below.

Finally the client has to be started with the volume bound, the correct role and the address to use.

```sh
$ mkdir -p ./config/keys/FuseNetwork
$ cp /path/to/my/key ./config/keys/FuseNetwork/
$ echo "mysupersecretpassphrase" > ./config/pass.pwd
$ mkdir ./database
## Start parity container with all necessary arguments.
$ docker run \
    --detach \
    --name fusenet \
    --volume $(pwd)/fusenet/database:/data \
    --volume $(pwd)/fusenet/config:/config/custom \
    -p 30303:30300/tcp \
    -p 30303:30300/udp \
    -p 8545:8545 \
    --restart=always \
    fusenet/node \
    --role validator \
    --address $address
```

As part of validator's responsibilities in the network, two more containers need to be started along side the Parity node.

One is the [validator-app](https://github.com/fuseio/fuse-network/tree/master/app)

```
## Start validator-app container with all necessary arguments.
$ docker run \
    --detach \
    --name fuseapp \
    --volume $(pwd)/fusenet/config:/config/custom \
    --restart=always \
    fusenet/validator-app
```

Second one is the [bridge-oracle](https://github.com/fuseio/bridge-oracle)

```
$ wget -O docker-compose.yml https://raw.githubusercontent.com/fuseio/bridge-oracle/master/docker-compose.keystore.yml
## Start oracle container with all necessary arguments.
$ docker-compose up \
    --build \
    -d
  ;;
```

##### Create New Account

If you have no existing account or a new one should be created anyway, _Parity_ could be used to do so.

Please consider other options like [MetaMask](https://metamask.io/) or any other (online) wallet tool.

In relation to the instructions for the [validator](#validator) role, we use the folder called `config` to bind as _Docker_ volume to _Parity_.

Afterwards the key will be placed there and the first steps of these instructions can be skipped.

```sh
$ mkdir ./config
$ docker run -ti -v $(pwd)/config/:/config/custom fusenet/node --parity-args account new
```

_Parity_ will ask for a password, that should be stored by you into `./config/pass.pwd` afterwards.

The address corresponding to the generated private key gets printed out on the CLI at the last line starting with `0x`.

Please copy it for the later use. It will be needed for the `--address` argument where it will be added in plain text.

##### Archival node

If you intent to run an archival node, for example for the explorer [blockscout explorer](https://github.com/fuseio/blockscout/tree/fuse):

```
## Start parity container with all necessary arguments.
$ docker run \
	--detach \
	--name fusenet \
    --volume $(pwd)/fusenet/database:/data \
    --volume $(pwd)/fusenet/config:/config/custom \
	-p 30303:30300/tcp \
	-p 30303:30300/udp \
	-p 8545:8545 \
	-p 8546:8546 \
	--restart=always \
	fusenet/node \
	--role explorer \
	--parity-args --node-key $NODE_KEY
```

**_Note_**

All roles should also run a [Ethereum Network Intelligence API](https://github.com/fuseio/eth-net-intelligence-api) app as well, in order to connect themselves as part of the network and be viewed by the [health](https://health.fuse.io) service\*\*\*

```
$ docker run \
    --detach \
    --name fusenetstat \
    --net=container:fusenet \
    --restart=always \
    fusenet/netstat \
    --instance-name $INSTANCE_NAME
```

## Building containers

The [buildContainers script](https://github.com/fuseio/fuse-network/blob/master/scripts/buildContainers.sh) is used to automate the process of building containers and version control within this repo.

```
1.  cd into the scripts directory
2.  run the script with elevated privileges (./buildConatiner.sh) - an on screen prompt will be displayed
3.  (skip if not first time) If running for the first time the script will need to install it's dependencies  this is done by selecting option 4
    ("First time configure")
4.  You are given 3 options ("Build Fuse APP container", "Build Fuse Parity container" and "Build both") select the appropriate option
5.  The script will build the containers and ask you for the new version info in the format x.y.z (where x,y,z are numbers). It will then push the
    newly built and tagged containers to the fusenet docker repo
6.  (optional) A Y/N prompt is given to update the fuse git repo with the new version info. if Y is selected the script will branch at your current
    head and create and commit the new version file and also create a PR to merge this file back into master (you may be required to input your git creds here)
```
