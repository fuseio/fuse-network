# Fuse Network - Nethermind

This custom script is designed to help you easily bootstrap your own node for either the Fuse mainnet or the Spark testnet.

Please check the minimum system requirements for Nethermind [here](https://docs.nethermind.io/validators/#hardware-configurations), and disk speed [here](https://docs.nethermind.io/get-started/system-requirements/#disk-speed).

## Description

> **Note:** Currently, the script supports the following roles: `node`, `bootnode`, `explorer` and `validator`.

```bash
./quickstart.sh

The Fuse Client - Bootstrap Your Own Node

Description:
  This script allows you to run your own Fuse node locally based on a specified role.

Note:
  quickstart.sh supports the following Linux/Unix-based distributions: Ubuntu, Debian, Fedora, CentOS, RHEL.

Usage:
  ./quickstart.sh [-r|-n|-k||-v|-h|-u|-m]

Options:
  -r  Specify the node role. Available roles: 'node', 'bootnode', 'explorer', 'validator'
  -n  Network (mainnet or testnet). Available values: 'fuse' and 'spark'
  -k  Node key name for https://health.fuse.io. Example: 'my-own-fuse-node'
  -v  Script version
  -u  Unjail a node (Validator only)
  -m  Flag a node for maintenance (Validator only)
  -h  Help page
```

## How to run

```bash
wget -O quickstart.sh https://raw.githubusercontent.com/fuseio/fuse-network/master/nethermind/quickstart.sh
chmod 755 quickstart.sh
```

```bash
./quickstart.sh -r [node_role] -n [network_name] -k [node_key]
```

> **Note:** If the node is already configured, repeating this step with the same arguments will update the client if a new version is available.

### Examples:

```bash
# Run node for Fuse (Mainnet)
./quickstart.sh -r node -n fuse -k fusenet-node

# Run bootnode for Spark (Testnet)
./quickstart.sh -r bootnode -n spark -k fusenet-spark-bootnode

# Unjail a node
./quickstart.sh -u

# Flag a node for maintenance
./quickstart.sh -m
```

## Health Dashboard

The node should appear on the [health dashboard](https://health.fuse.io) and can be monitored there.

> For testnet: [Spark health dashboard](https://health.fusespark.io/)

Additionally, configure Nethermind monitoring by following the instructions [here](https://docs.nethermind.io/monitoring/metrics/grafana-and-prometheus).

## Nethermind DB Snapshot

| Network | Type     | Location                                                                     |
| ------- | -------- | ---------------------------------------------------------------------------- |
| Fuse    | FastSync | https://storage.cloud.google.com/fuse-node-snapshot/nethermind/database.zip  |
| Spark   | FastSync | https://storage.cloud.google.com/spark-node-snapshot/nethermind/database.zip |

---
