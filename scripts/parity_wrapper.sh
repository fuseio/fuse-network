#!/bin/bash
#
# NAME
#   Parity Wrapper
#
# SYNOPSIS
#   parity_wrapper.sh [-r] [role] [-a] [address] [-p] [arguments]
#
# DESCRIPTION
#   A wrapper for the actual Parity client to make the Docker image easy usable by preparing the Parity client for
#   a set of predefined list of roles the client can take without have to write lines of arguments on run Docker.
#
# OPTIONS
#   -r [--role]         Role the Parity client should use.
#                       Depending on the chosen role Parity gets prepared for that role.
#                       Selecting a specific role can require further arguments.
#                       Checkout ROLES for further information.
#
#   -a [--address]      The Ethereum address that parity should use.
#                       Depending on the chosen role, the address gets inserted at the right place of the configuration, so Parity is aware of it.
#                       Gets ignored if not necessary for the chosen role.
#
#   -p [--parity-args]  Additional arguments that should be forwarded to the Parity client.
#                       Make sure this is the last argument, cause everything after is forwarded to Parity.
#
# ROLES
#   The list of available roles is:
#
#   bootnode
#     - No mining.
#     - RPC ports open.
#     - Does not require the address argument.
#     - Does not need the password file and the key-set. (see FILES)
#   node
#     - No mining.
#     - RPC ports open.
#     - Does not require the address argument.
#     - Does not need the password file and the key-set. (see FILES)
#
#   validator
#     - Connect as authority to the network for validating blocks.
#     - Miner.
#     - RPC ports open.
#     - Requires the address argument.
#     - Needs the password file and the key-set. (see FILES)
#
#   explorer
#     - No mining.
#     - RPC ports open.
#     - Does not require the address argument.
#     - Does not need the password file and the key-set. (see FILES)
#     - Some of Parity's settings are configured specifically for the use of blockscout explorer.
#
# FILES
#   The configuration folder for Parity takes place at /home/parity/.local/share/io.parity.ethereum.
#   Alternately the shorthand symbolic link at /config can be used.
#   Parity's database is at /home/parity/.local/share/io.parity.ethereum/chains or available trough /data as well.
#   To provide custom files in addition bind a volume through Docker to the sub-folder called 'custom'.
#   The password file is expected to be placed in the custom configuration folder names 'pass.pwd'.
#   The key-set is expected to to be placed in the custom configuration folder under 'keys/FuseNetwork/'
#   Besides from using the pre-defined locations, it is possible to define them manually thought the parity arguments. Checkout their documentation to do so.

# Create an array by the argument string.
IFS=' ' read -r -a ARG_VEC <<< "$@"

# Adjustable configuration values.
ROLE="node"
ADDRESS=""
GENERATE_NEW_ACCOUNT=false
PARITY_ARGS="--no-color"

# Internal stuff.
declare -a VALID_ROLE_LIST=(
                            bootnode
                            node
                            validator
                            explorer
                           )

# Configuration snippets.
CONFIG_SNIPPET_BOOTNODE='
[rpc]
cors = ["all"]
port = 8545
interface = "all"
hosts = ["all"]
apis = ["web3", "eth", "net", "parity", "traces", "rpc", "secretstore"]

[websockets]
disable = false
port = 8546
interface = "all"
origins = ["all"]
hosts = ["all"]
apis = ["web3", "eth", "net", "parity", "pubsub", "traces", "rpc", "secretstore"]

[network]
port = 30300
'

CONFIG_SNIPPET_NODE='
[rpc]
cors = ["all"]
port = 8545
interface = "all"
hosts = ["all"]
apis = ["web3", "eth", "net", "parity", "traces", "rpc", "secretstore"]

[websockets]
disable = false
port = 8546
interface = "all"
origins = ["all"]
hosts = ["all"]
apis = ["web3", "eth", "net", "parity", "pubsub", "traces", "rpc", "secretstore"]

[network]
port = 30300
reserved_peers="/home/parity/.local/share/io.parity.ethereum/bootnodes.txt"
'

CONFIG_SNIPPET_VALIDATOR='
[rpc]
cors = ["all"]
port = 8545
interface = "all"
hosts = ["all"]
apis = ["web3", "eth", "net", "parity", "traces", "rpc", "secretstore"]

[websockets]
disable = true

[network]
port = 30300
reserved_peers="/home/parity/.local/share/io.parity.ethereum/bootnodes.txt"

[account]
password = ["/home/parity/.local/share/io.parity.ethereum/custom/pass.pwd"]

[mining]
reseal_on_txs = "none"
force_sealing = true
engine_signer = "%s"
min_gas_price = 10000000000
gas_floor_target = "20000000"
'

CONFIG_SNIPPET_EXPLORER_NODE='
[rpc]
cors = ["all"]
port = 8545
interface = "all"
hosts = ["all"]
apis = ["web3", "eth", "net", "parity", "traces", "rpc", "secretstore"]

[websockets]
disable = false
port = 8546
interface = "all"
origins = ["all"]
hosts = ["all"]
apis = ["web3", "eth", "net", "parity", "pubsub", "traces", "rpc", "secretstore"]

[footprint]
tracing = "on"
pruning = "archive"
fat_db = "on"

[network]
port = 30300
reserved_peers="/home/parity/.local/share/io.parity.ethereum/bootnodes.txt"
'

# Make sure some environment variables are defined.
[[ -z "$PARITY_BIN" ]] && PARITY_BIN=/usr/local/bin/parity
[[ -z "$PARITY_CONFIG_FILE_NODE" ]] && PARITY_CONFIG_FILE_NODE=/home/parity/.local/share/io.parity.ethereum/config-template.toml
PARITY_CONFIG_FILE=/home/parity/.local/share/io.parity.ethereum/config.toml


# Print the header of this script as help.
# The header ends with the first empty line.
#
function printHelp {
  local file="${BASH_SOURCE[0]}"
  cat "$file" | sed -e '/^$/,$d; s/^#//; s/^\!\/bin\/bash//'
}

# Check if the defined role for the client is valid.
# Use a list of predefined roles to check for.
# In case the selected role is invalid, it prints our the error message and exits.
#
function checkRoleArgument {
  # Check each known role and end if it match.
  for i in "${VALID_ROLE_LIST[@]}" ; do
    [[ $i == $ROLE ]] && return
  done

  # Error report to the user with the correct usage.
  echo "The defined role ('$ROLE') is invalid."
  echo "Please choose of the following: ${VALID_ROLE_LIST[@]}"
  exit 1
}

# Parse the arguments, given to the script by the caller.
# Not defined configuration values stay with their default values.
# A not known argument leads to an exit with status code 1.
#
# Arguments:
#   $1 - all arguments by the caller
#
function parseArguments {
  for (( i=0; i<${#ARG_VEC[@]}; i++ )) ; do
    arg="${ARG_VEC[i]}"
    nextIndex=$((i + 1))

    # Print help and exit if requested.
    if [[ $arg == --help ]] || [[ $arg == -h ]] ; then
      printHelp
      exit 0

    # Define the role for the client.
    elif [[ $arg == --role ]] || [[ $arg == -r ]] ; then
      ROLE="${ARG_VEC[$nextIndex]}"
      checkRoleArgument # Make sure to have a valid role.
      i=$nextIndex

    # Define the address to bind.
    elif [[ $arg == --address ]] || [[ $arg == -a ]] ; then
      # Take the next argument as the address and jump other it.
      ADDRESS="${ARG_VEC[$nextIndex]}"
      i=$nextIndex
      PARITY_ARGS="$PARITY_ARGS --node-key ${ADDRESS}"

    # Additional arguments for the Parity client.
    # Use all remain arguments for parity.
    elif [[ $arg == --parity-args ]] || [[ $arg == -p ]] ; then
      PARITY_ARGS="$PARITY_ARGS ${ARG_VEC[@]:$nextIndex}"
      GENERATE_NEW_ACCOUNT=true
      i=${#ARG_VEC[@]}

    # A not known argument.
    else
      echo Unkown argument: $arg
      exit 1
    fi
  done
}


# Adjust the configuration file for parity for the selected role.
# Includes some checks of the arguments constellation and hints for the user.
# Use the predefined configuration snippets filled with the users input.
#
function adjustConfiguration {
  # Make sure role is defined
  if [[ -z "$ROLE" ]] && [[ $GENERATE_NEW_ACCOUNT != "true" ]] ; then
    echo "Missing or empty role!"
    echo "Make sure the argument order is correct (parity arguments at the end)."
    exit 1
  fi

  # Make sure an address is given if needed.
  if ( [[ $ROLE = 'validator' ]] ) && [[ -z "$ADDRESS" ]] ; then
    echo "Missing or empty address but required by selected role!"
    echo "Make sure the argument order is correct (parity arguments at the end)."
    exit 1
  fi

  # Read in the template.
  local template=$(cat $PARITY_CONFIG_FILE_TEMPLATE)

  # Handle the different roles.
  # Append the respective configuration snippet with the necessary variable to the default configuration file.
  case $ROLE in
    "bootnode")
      echo "Run as bootnode"
      printf "$template\n$CONFIG_SNIPPET_BOOTNODE" > $PARITY_CONFIG_FILE
      ;;

    "node")
      echo "Run as node"
      printf "$template\n$CONFIG_SNIPPET_NODE" > $PARITY_CONFIG_FILE
      ;;

    "validator")
      echo "Run as validator with address ${ADDRESS}"
      printf "$template\n$CONFIG_SNIPPET_VALIDATOR" "$ADDRESS" > $PARITY_CONFIG_FILE
      ;;

    "explorer")
      echo "Run as explorer node"
      printf "$template\n$CONFIG_SNIPPET_EXPLORER_NODE" > $PARITY_CONFIG_FILE
      ;;
  esac
}

# Caller of the actual Parity client binaries.
# The provided arguments by the user gets forwarded.
#
function runParity {
  echo "Start Parity with the following arguments: '${PARITY_ARGS}'"
  exec $PARITY_BIN $PARITY_ARGS
}


# Getting Started
parseArguments
adjustConfiguration
runParity