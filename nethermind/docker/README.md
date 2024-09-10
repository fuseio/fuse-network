# Nethermind - Docker

 This folder contains the Docker setup to run a Nethermind-based blockchain node. The project is organized into sub-folders for easy management of the Nethermind client and a monitoring stack.


## Folder Structure

 - **client/**  
  Contains the configuration and files needed to run the Nethermind blockchain client in various node roles, including standard nodes, bootnodes, archive nodes, and validator nodes.

 - **monitoring/**  
  Contains the necessary files for running a monitoring stack based on Prometheus, Grafana, and Seq to monitor the performance, logs and health of the Nethermind nodes.

 Each sub-folder contains Docker configuration files to quickly spin up the required services and node roles. You can easily run the desired Nethermind client configuration and monitoring stack using Docker Compose.

 Refer to the individual `README.md` files in each sub-folder for specific setup instructions and configuration details.


## Requirements
 
 Before you begin, ensure your environment meets the following requirements:

 - **Docker** and **Docker Compose** installed.  
  Supports both Docker Compose v1 and v2. You can install them from the official Docker documentation:  
  [Install Docker](https://docs.docker.com/get-docker/)  
  [Install Docker Compose](https://docs.docker.com/compose/install/)

 - Your server should be compatible with the minimal [Nethermind system requirements](https://docs.nethermind.io/get-started/system-requirements). Ensure that your hardware and OS configurations align with these requirements for optimal performance.

 - For running a `validator` node, a JSON-based wallet and a wallet password file are required to sign and validate blocks.


## Move setup from quickstart.sh to the Docker Compose stack

 There is the description how to migrate the node from `quickstart.sh` to the Docker Compose stack. Let's imagine that you have `validator` node role. Your folder's structure is:

 - `[root_folder]/quickstart.sh` - quickstart bash file to run the blockchain node;

 - `[root_folder]/fusenet/database` - blockchain node ledger;

 - `[root_folder]/fusenet/keystore` - blockchain node private key (wallet);

 - `[root_folder]/fusenet/logs` - blockchain client logs.

 ---

 There are the next steps to migrate everything smoothly:

 - Login on the server and stop your existing setup;
 
 - Clone GitHub repository:

 ```bash
 git clone https://github.com/fuseio/fuse-network.git
 ```

 - As a convention each optional packages should be stored in `/opt` folder. Create the folder `/opt/nethermind/[network]`:

 ```bash
 mkdir -p /opt/nethermind/fuse
 ```

 - Copy (enough disk space is required) the folders `[root_folder]/fusenet/database` and `[root_folder]/fusenet/keystore` to the new directory;

 - From cloned repository copy `docker-compose.validator.yaml`, `.validator.env` and `processes.json` files to the new directory;

 - The new folder structure should be:

 ```bash
 ls -a /opt/nethermind/fuse
 . database docker-compose.validator.yaml
 .. keystore processes.json .validator.env
 ```

 - In the .validator.env file specify the next environment variables (variables already have specified, just need to provide values compatible with your setup):

 ```bash
 # Netstats instance name. Example: 'fuse-nethermind-validator-1_[wallet_address]'
 INSTANCE_NAME=fuse-nethermind-validator-1_[wallet_address]
 
 # Netstats contact details. Example: 'hello@nethermind.io'
 CONTACT_DETAILS=[contact_details]

 # Keystore (required for 'validator' node role, for empty variables specify wallet address)
 NETHERMIND_KEYSTORECONFIG_BLOCKAUTHORACCOUNT=[wallet_address]
 NETHERMIND_KEYSTORECONFIG_ENODEACCOUNT=[wallet_address]
 NETHERMIND_KEYSTORECONFIG_PASSWORDFILES=keystore/pass.pwd
 NETHERMIND_KEYSTORECONFIG_UNLOCKACCOUNTS=[wallet_address]
 ```

 - Run everything:

 ```bash
 docker-compose -f docker-compose.validator.yaml --env-file .validator.env up -d
 ```

 There are 3 Docker containers should be up and running: `nethermind`, `netstats` and `validator`.

 Almost the same approach looks for the other node roles. The difference is no need to specify the private key (wallet) parameters.
