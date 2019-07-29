# Fuse Network

- [General](#general)
  - [Clone Repository](#clone-repository)
  - [Install Dependencies](#install-dependencies)
  - [Run Unit Tests](#run-unit-tests)
- [Contracts](#contracts)
  - [Documentation](https://github.com/fuseio/fuse-network/blob/master/CONTRACTS.md)
  - [Compile](#compile)
  - [Flatten](#flatten)
  - [Deploy](#deploy)
- [Run Local Node](#run-local-node)
  - [Pre-Requisites](#pre-requisites)
  - [Hardware](#hardware) 
  - [Quickstart](#using-quickstart)
  - [Using Docker](#using-docker)
    - [Usage](#usage)
    - [Examples](#examples)
    - [Bootnode](#bootnode)
    - [Validator](#validator)
    - [Create New Account](#create-new-account)
    - [Explorer node](#explorer-node)
  - [Without Docker](#without-docker)
    - [Creating An Account](#creating-an-account)
    - [Setup For Bootnodes Using Only CLI](#setup-for-bootnodes-using-only-cli)
    - [Setup For Validators Using Only CLI](#setup-for-validators-using-only-cli)
    - [Setup For Explorer Node Using Only CLI](#setup-for-explorer-node-using-only-cli)
- [Validators App](https://github.com/fuseio/fuse-network/tree/master/app/README.md)
- [Development](#development)
  - [Build Own Image](#build-own-image)
  - [Upload Image](#upload-image)

## General
### Clone Repository
```
$ git clone https://github.com/fuseio/fuse-network.git ~/Dev/fuse-network
```

### Install Dependencies
```
$ npm install
```

### Run Unit Tests
```
$ npm test
```

## Contracts
### Compile
```
$ npm run compile
```

### ABIs
```
$ npm run abi
```

### Flatten
```
$ npm run flatten
```

### Deploy
Make sure `NETWORK_NAME` is defined in [`truffle-config`](https://github.com/fuseio/fuse-network/blob/master/truffle-config.js)

Make sure you've created an `.env` using the template [`env.example`](https://github.com/fuseio/fuse-network/blob/master/.env.example)

Run:

```
$ ./node_modules/.bin/truffle migrate --reset --network <NETWORK_NAME>
```

## Run Local Node

Please make sure you have access to a continuously running machine, if you like to participate as a network validator.

### Pre-Requisites

A complete [Docker](https://www.docker.com/) environment is needed to be installed on your system.

Please take a look into the [official documentation](https://docs.docker.com/install/#general-availability) and use the instructions for your respective OS.

Make sure that your user is added to the `docker` user-group on _Unix_ systems, if you can't access root permissions to run containers.

### Hardware
*Note: specified for [Microsoft Azure](https://portal.azure.com), but similar on other providers as well*

##### Bootnode (or Explorer Node)

* OS - `Linux (ubuntu 18.04)`
* Size - `Standard B2ms (2 vcpus, 8 GiB memory)`
* Disk - `30 GiB Premium SSD`
* Networking

```
| Priority 	| Description                    	| Port  	| Protocol 	| Source                  	| Destination    	| Action 	|
|----------	|--------------------------------	|-------	|----------	|-------------------------	|----------------	|--------	|
| 1000     	| ssh	                            | 22    	| TCP      	| ip list comma-separated 	| Any            	| Allow  	|
| 1001     	| p2p                            	| 30303 	| TCP      	| Any                     	| Any            	| Allow  	|
| 1002     	| p2p udp                        	| 30303 	| UDP      	| Any                     	| Any            	| Allow  	|
| 1003     	| rpc                            	| 8545  	| TCP      	| Any                     	| Any            	| Allow  	|
| 1004     	| https                          	| 443   	| TCP      	| Any                     	| Any            	| Allow  	|
| 1005     	| http                           	| 80    	| TCP      	| Any                     	| Any            	| Allow  	|
| 65000    	| AllowVnetInBound               	| Any   	| Any      	| VirtualNetwork          	| VirtualNetwork 	| Allow  	|
| 65001    	| AllowAzureLoadBalancerInBound  	| Any   	| Any      	| AzureLoadBalancer       	| Any            	| Allow  	|
| 65500    	| DenyAllInBound                 	| Any   	| Any      	| Any                     	| Any            	| Deny   	|
```

##### Validator

* OS - `Linux (ubuntu 18.04)`
* Size - `Standard D2s v3 (2 vcpus, 8 GiB memory)`
* Disk - `30 GiB Premium SSD`
* Networking

```
| Priority 	| Description                    	| Port  	| Protocol 	| Source                  	| Destination    	| Action 	|
|----------	|--------------------------------	|-------	|----------	|-------------------------	|----------------	|--------	|
| 1000     	| ssh	                            | 22    	| TCP      	| ip list comma-separated 	| Any            	| Allow  	|
| 1001     	| p2p                            	| 30303 	| TCP      	| Any                     	| Any            	| Allow  	|
| 1002     	| p2p udp                        	| 30303 	| UDP      	| Any                     	| Any            	| Allow  	|
```

### Using Quickstart

To make starting a node for the FuseNetwork as quick as possible, the _quickstart_ script can be used.

Simply download and run the script.

The script will make sure to have everything that is necessary, create a new account for you (if needed) and start the _Parity_ client with all requested arguments.

The script can be called multiple times without problems, so it checks what is already there and will at least update all service processes.

_Parity_ will restart automatically on fails.

```sh
$ wget -O quickstart.sh https://raw.githubusercontent.com/fuseio/fuse-network/master/scripts/quickstart.sh
$ chmod 777 quickstart.sh
$ ./quickstart.sh --role <ROLE>
```

Follow the instructions emitted by the script.

If you want to restart the node or want to make sure it runs on the most recent version, just re-run the script.

---

### Using Docker

The following instructions explain how to start a local node with the _Docker_ image.

In fact it uses a pre-configured [Parity Ethereum](https://www.parity.io/) client, combined with a set-up wrapper, to make connecting as easy as possible.

The image is prepared to be used as bootnode, validator or explorer node.

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
	#
	#   validator
	#     - Connect as authority to the network for validating blocks.
	#     - Miner.
	#     - RPC ports closed.
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
If you want to run a bootnode for the network, it only needs to have RPC and WS ports mapped out of the docker to the local machine, no account address is needed.

```
$ docker run -ti -v $(pwd)/database:/data -v $(pwd)/config:/config/custom -p 30300:30300 -p 8545:8545 -p 8546:8546 fusenet/node --role bootnode --parity-args --node-key UNIQUE_NAME_FOR_NODE
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
$ docker run -ti -v $(pwd)/database:/data -v $(pwd)/config:/config/custom -p 30300:30300 fusenet/node --role validator --address MY_ADDRESS
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

##### Explorer node
If you want to run a node to be used by the [blockscout explorer](https://github.com/fuseio/blockscout/tree/fuse) run the following command:

```
$ docker run -ti -v $(pwd)/database:/data -v $(pwd)/config:/config/custom -p 30300:30300 -p 8545:8545 -p 8546:8546 fusenet/node --role explorer --parity-args --node-key UNIQUE_NAME_FOR_EXPLORER_NODE
```
---

### Without Docker

This section explains how to start a local node without using the _Docker_ image.

#### Pre-Requisites

- [Parity version 2.4.5](https://github.com/paritytech/parity-ethereum/releases/tag/v2.4.5)
- [spec.json](https://github.com/fuseio/fuse-post-network/blob/master/config/spec.json) file

#### Creating An Account

To interact with the FuseNetwork chain, one needs a private key corresponding to an address usable on the chain.

If you already possess such a key, you can skip this section.

To start with, create a folder to store everything related to the FuseNetwork chain, move the `spec.json` file to this folder and change to this folder:

```sh
mkdir fusenetwork-chain
mv spec.json fusenetwork-chain/spec.json
cd fusenetwork-chain
```

You can then create an account with the command:

```sh
parity account new --chain spec.json -d [path/to/node/foler]
```

For the rest of this documentation to become a validator we will assume you ran:

```sh
parity account new --chain spec.json -d validator_node
```

You will be prompted to enter a password twice to protect this private key.

You need to remember this password and use it whenever you want to use the private key.

After successfully creating an account, you will see displayed the public address corresponding to that account (in format `0x6c...e6`), keep that address somewhere.

For running a node as a validator, you will need to store your password in a file.

```sh
echo [mypassword] > password.pwd
```

#### Setup For Bootnode Using Only CLI
> TODO

#### Setup For Validator Using Only CLI
> TODO

#### Setup For Explorer Node Using Only CLI
> TODO

## Development

### Build Own Image

To build the _Docker_ image, checkout this repository and run `docker build` with your preferred tag name. As the context of the build must be the project root, the path to the `Dockerfile` has to be specified manually.

```sh
$ git clone https://github.com/fuseio/fuse-network
$ docker build -f docker/Dockerfile -t MY_TAGNAME .
$ docker run ... MY_TAGNAME ...
```

### Upload Image

The built image is publicly available at [DockerHub](https://hub.docker.com/).

To upload a new version make sure to have access to the _fuse_ organization.

If permissions are given, the local build has to be tagged and then pushed.

Please replace `USERNAME` with your own account name on _DockerHub_ and `LOCAL_IMAGE` with the tag name you have given the image while building.

The example below uses the `:latest` tag postfix which is the default one used by _DockerHub_ when pulling an image.

If you want to provide an additional tag (e.g. for sub-versions), adjust the name when tagging.

```sh
$ echo "yoursecretpassword" | docker login --username USERNAME --password-stdin
$ docker tag LOCAL_IMAGE fusenet/node:latest
$ docker push fusenet/node:latest
```
