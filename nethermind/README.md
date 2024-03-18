# Fuse Network - Nethermind

This custom .sh script is designed to help you easily bootstrap your own node for either the Fuse mainnet or the Spark testnet.

> Note: at this moment script supports next roles: `node`, `bootnode`, `explorer`.

## Description

```bash
./quickstart.sh

The Fuse client - Bootstrap your own node.

Description:
  Script allow to run locally your own Fuse node based on specific role.

Note:
  quickstart.sh supports next Linux / Unix based distributions: Ubuntu, Debian, Fedora, CentOS, RHEL.

Usage:
  ./quickstart.sh [-r|-n|-k||-v|-h|-u|-m]

Options:
  -r  Specify needed node role. Available next roles: 'node', 'bootnode', 'explorer'
  -n  Network (mainnet or testnet). Available next values: 'fuse' and 'spark'
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

Examples:

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
