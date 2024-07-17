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
      - [Nethermind](#nethermind)

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
> - Outbound traffic should be opened for all IP addresses
> - For Bootnode node role not necessary to open RPC and WebSocket ports, only P2P are required; for Validator node role WebSocket and RPC ports should be opened on `localhost` and granted restricted access through IP whitelists

### Snapshot

 To speed up node sync there are the snapshot download links.

 | Endpoint                       | Network | Type      | Direct link (latest)                                |
 | ------------------------------ | ------- | --------- | --------------------------------------------------- |
 | https://snapshot.fuse.io       | Fuse    | FastSync  | https://snapshot.fuse.io/openethereum/database.zip  |

 The archive file contains `database` folder, blockchain ledger, with n blocks depending on the snapshot date.

 > Note: Fuse snapshot compatible with OpenEthereum v3.3.5, Docker image `fusenet/node:2.0.2`.

### Using Quickstart

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
