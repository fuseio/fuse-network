# Migrating from OpenEthereum to Nethermind Client

## Introduction

This guide provides step-by-step instructions for node operators looking to migrate their Fuse nodes from the OpenEthereum client to the Nethermind client. The migration process involves flagging the node for maintenance, backing up data, installing the Nethermind client, configuring it, and finally starting and verifying the node's operation.

## Prerequisites

- An operational Ethereum node running the OpenEthereum client.
- Sufficient storage space for blockchain data.
- Basic command-line interface (CLI) knowledge.

## Step 1: Flagging for Maintenance (Validator Nodes Only)

Before starting the migration, flag your node for maintenance to ensure it is removed from the active set.

1. **Flag the node for maintenance** using the following command:

   ```bash
   ./quickstart.sh -m
   ```

2. **Wait for the validator node to be out of the active set**, which will take effect on the next cycle. To get the current cycle end block, use the following command:

   ```bash
   curl --location 'https://rpc.fuse.io/' \
   --header 'Content-Type: application/json' \
   --data '{
     "jsonrpc": "2.0",
     "id": 1,
     "method": "eth_call",
     "params": [
       {
         "to": "0x3014ca10b91cb3D0AD85fEf7A3Cb95BCAc9c0f79",
         "data": "0xaf295181"
       },
       "latest"
     ]
   }'
   ```

3. **To check if the validator node is no longer in the validation set**, use the following command:
   ```bash
   curl --location 'https://rpc.fuse.io/' \
   --header 'Content-Type: application/json' \
   --data '{
     "jsonrpc": "2.0",
     "id": 1,
     "method": "eth_call",
     "params": [
       {
         "to": "0x3014ca10b91cb3D0AD85fEf7A3Cb95BCAc9c0f79",
         "data": "0xfacd743b000000000000000000000000"
       },
       "latest"
     ]
   }'
   ```

## Step 2: Backing Up Your Node Data

Once the node is flagged for maintenance and out of the active set, proceed to back up your node data. This includes the blockchain data and keys.

**This backup is to revert to OpenEthereum in case of migration failure.**

> In this guide, we will assume the containers are named fusenet, netstats, fuseapp (Validator Nodes Only).

1. **Navigate to the [health](https://health.fuse.io/)** dashboard and verify that the node is healthy.
2. **Check the logs** to verify the node's health:

   ```bash
   docker logs fusenet -f
   ```

   - **Things to look for:**
     - Operating mode: active
     - Not preparing block; cannot sign. (if you are not running a validator node)
     - Configured for FuseNetwork using the AuthorityRound engine
     - Syncing #[Block-Number]

3. **Identify running containers** by executing the command below:

   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
   ```

4. **Stop your OpenEthereum node** to ensure data integrity during the backup process:

   ```bash
   docker stop fusenet netstats fuseapp
   ```

   > **Important**: The OpenEthereum node must be stopped to allow migration.

5. **Backup your data directory**. This directory contains the blockchain data and keys. The folder structure should be similar to the below:

   > Please be aware that the names of the folders may differ depending on your initial setup.

   - fusenet/database
   - fusenet/config/keystore
     - node.key.plain
     - pass.pwd
     - UTC--[Date]--xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx

   > The database backup from the OpenEthereum node cannot be used for Nethermind. It is to revert to OpenEthereum in case of migration failure.

## Step 3: Copying the Keystore Directory

Create a new folder for Nethermind and copy the keystore directory from the OpenEthereum node. This step is crucial to ensure your keys are correctly transferred.

1. **Create a new folder for Nethermind** in your home directory:

   ```bash
   mkdir ~/nethermind && cd ~/nethermind
   ```

2. **Copy the keystore directory** from the OpenEthereum node to the Nethermind directory:

   ```bash
   cp -r /path/to/openethereum/config/keystore ~/nethermind/config/keystore
   ```

   > **Note**: Ensure you replace `/path/to/openethereum/config/keystore` with the actual path to your OpenEthereum keystore directory.

3. **Optional**: To protect the keystore, you may want to change the permissions:
   ```bash
   chmod -R 700 ~/nethermind/config/keystore
   ```

## Step 4: Installing Nethermind

With your data backed up and the keystore directory copied, the next step is to install the Nethermind client. Please check the Nethermind [system requirements](https://docs.nethermind.io/get-started/system-requirements/) before continuing.

1. **Download the Nethermind quickstart.sh script**. Please refer to the [quickstart.sh guide](https://github.com/fuseio/fuse-network/tree/master/nethermind) for more details:

   ```bash
   wget -O quickstart.sh https://raw.githubusercontent.com/fuseio/fuse-network/master/nethermind/quickstart.sh
   chmod 755 quickstart.sh
   ```

2. **Install the Nethermind client** by following the guide above.
   > Please ensure the OpenEthereum node is not running and only one key is active at any time.
   ```bash
   ./quickstart.sh -r [node/validator] -n [fuse/spark] -k [node_name]
   ```

- **Things to look for:**
  - Running Docker container for the Fuse network. Role - .....
  - **Monitor** the command line while running the quickstart.sh script and verify that the public address matches the node address.

## Step 5: Syncing Nethermind

Syncing the Nethermind client from scratch can take several hours. Optionally, to speed up this process, you can use a database snapshot.

1. **Download the Nethermind DB Snapshot** from the link provided:

   | Network | Type     | Location                                                                    |
   | ------- | -------- | --------------------------------------------------------------------------- |
   | Fuse    | FastSync | https://storage.cloud.google.com/fuse-node-snapshot/nethermind/database.zip |

2. **Extract the snapshot** to the Nethermind database directory:

   ```bash
   unzip database.zip -d ~/nethermind/database
   ```

3. **Start the Nethermind client**:
   ```bash
   ./quickstart.sh -r [node/validator] -n [fuse/spark] -k [node_name]
   ```

## Step 6: Verifying the Migration

Once Nethermind is up and running, perform checks to ensure everything is working as expected.

1. **Check the keystore folder**. The keystore structure differs between the OE client and the Nethermind client. The quickstart.sh script will handle the keystore migration from the old structure to the new one supported by Nethermind.

   Use the `ls` command to view the folder structure:

   - nethermind/database
   - nethermind/logs
   - nethermind/config/keystore
     - `UTC--{yyyy-MM-dd}T{HH-mm-ss.ffffff}000Z--{address}`
       > Please verify the node address matches the address in the UTC file name above.
     - Verify that you have only one key file.

2. **Check the logs** by running the following commands:
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
   sudo docker logs fuse -f
   ```

- **Things to look for:**

  - Nethermind initialization completed.
  - Node address: 0x..........
  - Address 0x0.......... is configured for signing blocks. (Validator Nodes Only)
  - Skipping the creation of a new private key...
  - Verify that the public address matches the node address.
  - The node is sealing/syncing new blocks.

- **For validator app logs** (Validator Nodes Only):

  ```bash
  docker logs fuseapp
  ```

- **For netstats client logs**:
  ```bash
  docker logs netstats
  ```

## Support and Issues

If you encounter issues during the migration, please post an issue on [GitHub](https://github.com/fuseio/fuse-network/issues) and specify `[OE Migration]` in the title. This will help us identify and address migration-related issues more efficiently.