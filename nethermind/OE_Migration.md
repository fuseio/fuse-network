## Documentation Guide: Migrating from OpenEthereum to Nethermind Client

### Introduction

This guide provides step-by-step instructions for node operators looking to migrate their Fuse nodes from the OpenEthereum client to the Nethermind client. The migration process involves backing up data, installing the Nethermind client, configuring it, and finally starting and verifying the node's operation.

### Prerequisites

- An operational Ethereum node running the OpenEthereum client.
- Sufficient storage space for blockchain data.
- Basic command-line interface (CLI) knowledge.

### Step 1: Backing Up Your Node Data

Before starting the migration, ensure you have a backup of your node data. This includes the blockchain data and keys.

> In this guide, we will assume the containers are named openethereum, netstats, fuseapp (if you are running a validator node).

1. **Navigate to the [health](https://health.fuse.io/)** dashboard and verify that the node is healthy.
2. **Check the logs** to verify the node's health.

```bash
docker logs openethereum -f
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
docker stop openethereum netstats fuseapp
```

5. **Backup your data directory**. This directory contains the blockchain data and keys. The folder structure should be similar to the below:
   > Please be aware that the names of the folders may differ depending on your initial setup.
   - fusenet/database
   - fusenet/config/keystore
     - node.key.plain
     - pass.pwd
     - UTC--[Date]--xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx

### Step 2: Installing Nethermind

With your data backed up, the next step is to install the Nethermind client. Please check the Nethermind [system requirements](https://docs.nethermind.io/get-started/system-requirements/) before continuing.

1. **Create a new folder for Nethermind** and copy the keystore directory from the OpenEthereum node.
   > It's advised to sync the database from scratch and not to use the backup from the OpenEthereum node.

```bash
mkdir nethermind && cd nethermind
```

2. **Download the Nethermind quickstart.sh script**. Please refer to the [quickstart.sh guide](https://github.com/fuseio/fuse-network/tree/master/nethermind) for more details.

```bash
wget -O quickstart.sh https://raw.githubusercontent.com/fuseio/fuse-network/master/nethermind/quickstart.sh
chmod 755 quickstart.sh
```

3. **Install the Nethermind client** by following the guide above.
   > Please ensure the OpenEthereum node is not running.

```bash
./quickstart.sh -r [node/validator] -n [fuse/spark] -k [node_name]
```

- **Things to look for:**
  - Running Docker container for the Fuse network. Role - .....
  - **Monitor** the command line while running the quickstart.sh script and verify that the public address matches the node address.

### Step 3: Verifying the Migration

Once Nethermind is up and running, perform checks to ensure everything is working as expected.

1. **Check the keystore folder**. The keystore structure differs between the OE client and the Nethermind client. The quickstart.sh script will handle the keystore migration from the old structure to the new one supported by Nethermind.

   Use the `ls` command to view the folder structure:

   - fusenet/database
   - fusenet/logs
   - fusenet/keystore
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
