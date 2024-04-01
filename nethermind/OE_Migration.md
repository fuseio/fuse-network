### Documentation Guide: Migrating from OpenEthereum to Nethermind Client

#### Introduction

This guide provides step-by-step instructions for node operators looking to migrate their Fuse nodes from the OpenEthereum client to the Nethermind client. The migration process involves backing up data, installing the Nethermind client, configuring it, and finally starting and verifying the node's operation.

#### Prerequisites

- An operational Ethereum node running OpenEthereum.
- Sufficient storage space for blockchain data.
- Basic command-line interface (CLI) knowledge.

#### Step 1: Backing Up Your Node Data

Before starting the migration, ensure you have a backup of your node data. This includes the blockchain data and keys.

1. **Stop your OpenEthereum node** to ensure data integrity during the backup process.
2. **Backup your data directory**. This directory contains the blockchain data and keys. Folder structure should be similar to the below:
   - fusenet/database
   - fusenet/keystore
     - node.key.plain
     - pass.pwd
     - UTC--[Date]--xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx

#### Step 2: Installing Nethermind

With your data backed up, the next step is to install the Nethermind client.

1. **Extract the downloaded file**; it's advised to sync the database from scratch and not to use the backup from OpenEthereum node.
2. **Download & install Nethermind**. Please refer to the [quickstart.sh guide](https://github.com/fuseio/fuse-network/tree/master/nethermind).
3. **Monitor** the command line while running the quickstart.sh script file and verify that the public address matches the node address.

- Things to look for
  - `Private key is present in the directory. Your public address 0x0..........`
  - `Skipping creating new private key...`

#### Step 5: Verifying the Migration

Once Nethermind is up and running, perform checks to ensure everything is working as expected.

1. **Check keystore folder**. The keystore structure is different between OE client and Nethermind client. The quickstart.sh script will handle the keystore migration from the old structure to the new one supported by Nethermind.

   - Under keystore folder the UTC file should follow this structure:
     - `UTC--{yyyy-MM-dd}T{HH-mm-ss.ffffff}000Z--{address}`
   - Verify that you have only one key file

2. **Check the logs**: Please run the below commands and check the logs

- To check the logs of the Nethermind client (assuming it's running under the container name `fusenet`):
  - Things to look for
    - `Address 0x0.......... is configured for signing blocks.` (if you are running a validator node)
    - `Address 0x0.......... is configured for .TODO.` (if you are **not** running a validator node)
    - Verify that the public address matches the node address.
    - The node is sealing/syncing new blocks.
  ```bash
  docker logs fusenet
  ```
- To check the logs of the validator app (if you are running a validator node):

  ```bash
  docker logs fuseapp
  ```

- To check the logs of the netstats client (assuming it's running under the container name `fusenetstat`):

  ```bash
  docker logs fusenetstat
  ```

#### Troubleshooting

- If you encounter issues during the migration, please reach out to us for support at nodes-support@fuse.io.
