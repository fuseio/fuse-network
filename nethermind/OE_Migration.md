## Documentation Guide: Migrating from OpenEthereum to Nethermind Client

### Introduction

This guide provides step-by-step instructions for node operators looking to migrate their Fuse nodes from the OpenEthereum client to the Nethermind client. The migration process involves flagging the node for maintenance, backing up data, installing the Nethermind client, configuring it, and finally starting and verifying the node's operation.

### Prerequisites

- An operational Ethereum node running the OpenEthereum client.
- Sufficient storage space for blockchain data.
- Basic command-line interface (CLI) knowledge.

### Step 1: Flagging for Maintenance

Before starting the migration, flag your node for maintenance to ensure it is removed from the active set.

1. **Flag the node for maintenance** using the following command:

```bash
./quickstart.sh -m
```

2. **Wait for the node to be out of the active set**. Monitor the status on the [health](https://health.fuse.io/) dashboard to ensure the node is no longer active.

### Step 2: Backing Up Your Node Data

Once the node is flagged for maintenance and out of the active set, proceed to back up your node data. This includes the blockchain data and keys.

**The backup is to revert to OpenEthereum in case of migration failure.**

> In this guide, we will assume the containers are named fusenet, netstats, fuseapp (if you are running a validator node).

1. **Navigate to the [health](https://health.fuse.io/)** dashboard and verify that the node is healthy.
2. **Check the logs** to verify the node's health.

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

   > It is advised to sync the database from scratch and not use the backup from the OpenEthereum node.

### Step 3: Copying the Keystore Directory

Create a new folder for Nethermind and copy the keystore directory from the OpenEthereum node. This step is crucial to ensure your keys are correctly transferred.

1. **Create a new folder for Nethermind** in your home directory.

```bash
mkdir ~/nethermind && cd ~/nethermind
```

2. **Copy the keystore directory** from the OpenEthereum node to the Nethermind directory.

```bash
cp -r /path/to/openethereum/config/keystore ~/nethermind/config/keystore
```

> **Note**: Ensure you replace `/path/to/openethereum/config/keystore` with the actual path to your OpenEthereum keystore directory.

3. **Optional**: To protect the keystore, you may want to change the permissions.

```bash
chmod -R 700 ~/nethermind/config/keystore
```

### Step 4: Installing Nethermind

With your data backed up and the keystore directory copied, the next step is to install the Nethermind client. Please check the Nethermind [system requirements](https://docs.nethermind.io/get-started/system-requirements/) before continuing.

1. **Download the Nethermind quickstart.sh script**. Please refer to the [quickstart.sh guide](https://github.com/fuseio/fuse-network/tree/master/nethermind) for more details.

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

  > **Estimate**: Syncing Nethermind may take 4-6 hours depending on server and network speed.

### Step 5: Verifying the Migration

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
  - Address 0x0.......... is configured for signing blocks. (if you are running a validator node)
  - Skipping the creation of a new private key...
  - Verify that the public address matches the node address.
  - The node is sealing/syncing new blocks.

- **For validator app logs** (if you are running a validator node):

```bash
docker logs fuseapp
```

- **For netstats client logs**:

```bash
docker logs netstats
```

### Troubleshooting

- If you encounter issues during the migration, please reach out to us for support at nodes-support@fuse.io.
