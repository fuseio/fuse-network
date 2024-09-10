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


## How-To

 How-To tutorials used to provide detailed info for Docker Compose setup usage.

### Deprecate quickstart.sh

 Update is coming.
