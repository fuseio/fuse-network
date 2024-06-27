Certainly! Here's the updated guide with the added step to remove the maintenance flag and verify that the node is starting to validate blocks again:

# Migrating from OpenEthereum to Nethermind Client

## Index

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Step 0: Avoid having two nodes with the same key!](#step-0-avoid-having-two-nodes-with-the-same-key)
- [Step 1: Flagging for Maintenance (Validator Nodes Only)](#step-1-flagging-for-maintenance-validator-nodes-only)
- [Step 2: Backing Up Your Node Data](#step-2-backing-up-your-node-data)
- [Step 3: Copying the Keystore Directory](#step-3-copying-the-keystore-directory)
- [Step 4: Installing Nethermind](#step-4-installing-nethermind)
- [Step 5: Syncing Nethermind](#step-5-syncing-nethermind)
- [Step 6: Verifying the Migration](#step-6-verifying-the-migration)
- [Step 7: Removing Maintenance Flag (Validator Nodes Only)](#step-7-removing-maintenance-flag-validator-nodes-only)
- [Support and Issues](#support-and-issues)

## Introduction

This guide provides step-by-step instructions for node operators looking to migrate their Fuse nodes from the OpenEthereum client to the Nethermind client. The migration process involves flagging the node for maintenance, backing up data, installing the Nethermind client, configuring it, and finally starting and verifying the node's operation.

## Prerequisites

- An operational Ethereum node running the OpenEthereum client.
- Sufficient storage space for blockchain data.
- Basic command-line interface (CLI) knowledge.

### In this guide, we will assume the containers are named fusenet, netstats, and **fuseapp** (Validator Nodes Only).

## Step 0: Avoid having two nodes with the same key!

> **⚠️ Important: Only One Instance of OpenEthereum or Nethermind Client Can Be Running with the Same Key. ⚠️**
>
> You must make sure that the OpenEthereum node is not running before starting the Nethermind node. Failure to do this will result in double signing, which can cause reorgs, potentially lead to consensus failure, and forking.

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

> **Important:** Please only proceed if the node is out of the active set.

## Step 2: Backing Up Your Node Data

This backup step is to revert to OpenEthereum in case of migration failure.

1. **Navigate to the [health](https://health.fuse.io/)** dashboard and verify that the node is healthy.
2. **Check the logs** to verify the node's health:

   ```bash
   docker logs fusenet -f
   ```

   - **Things to look for:**
     - Not preparing block (Validator Nodes Only)
     - Syncing #[Block-Number] is the latest.

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

   > **Note**: Please be aware that the names of the folders may differ depending on your initial setup.

   - fusenet/database
   - fusenet/config/keystore
     - `node.key.plain`
     - `pass.pwd`
     - `UTC--[Date]--xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx`

   > **Note**: The database backup from the OpenEthereum node cannot be used for Nethermind. It is to revert to OpenEthereum in case of migration failure.

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
   > **Important:** Please ensure the OpenEthereum node is not running and only one key is active at any time.
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
   - nethermind/database
   - nethermind/logs
   - nethermind/config/keystore
     - `UTC--{yyyy-MM-dd}T{HH-mm-ss.ffffff}000Z--{address}`
     - Verify that you have only one key file.

> **Note**: Please verify the node address matches the address in the UTC file name above.

2. **Check the logs** by running the following commands:
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
   sudo docker logs fuse -f
   ```

- **Things to look for:**

  - Nethermind initialization completed.
  - Node address: `0x..........`
  - Address `0x0..........` is configured for signing blocks. (Validator Nodes Only)
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

## Step 7: Removing Maintenance Flag (Validator Nodes Only)

After verifying that the Nethermind client is functioning correctly, remove the maintenance flag to re-enable validation.

1. **Remove the maintenance flag** using the following command:

   ```bash
   ./quickstart.sh -m
   ```

2. **Wait for the next cycle** for the node to rejoin the active validation set. Verify that the node is starting

to validate blocks again.

> **Note**: To check if the validator node is back in the validation set, use the commands mentioned in Step 1.

## Support and Issues

If you encounter any issues during the migration or have suggestions to improve this guide, please post an [issue](<(https://github.com/fuseio/fuse-network/issues)>) or create a pull request on this GitHub repo, using `[OE Migration]` in the title. This will help us promptly identify and address migration-related concerns.
