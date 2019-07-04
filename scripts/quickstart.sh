#!/bin/bash

set -e

# Create an array by the argument string.
IFS=' ' read -r -a ARG_VEC <<< "$@"

# Variables
DOCKER_IMAGE_PARITY="fusenetwork/fusenet"
DOCKER_CONTAINER_PARITY="fusenet"
DOCKER_IMAGE_APP="fusenetwork/fuseapp"
DOCKER_CONTAINER_APP="fuseapp"
PERMISSION_PREFIX="" # In case `sudo` is needed
BASE_DIR=$(pwd)/fusenet
DATABASE_DIR=$BASE_DIR/database
CONFIG_DIR=$BASE_DIR/config
ROLE=""
PASSWORD_FILE=$CONFIG_DIR/pass.pwd
PASSWORD=""
ADDRESS_FILE=$CONFIG_DIR/address
ADDRESS=""
NODE_KEY=""

declare -a VALID_ROLE_LIST=(
  bootnode
  validator
  explorer
)

# Function for some checks at the beginning to make sure everything will run well.
# This includes the check for commands, permissions and the environment.
# The checks can close the process with an error message or set additional options.
#
function sanityChecks {
  # Check if Docker is ready to use.
  if ! command -v docker>/dev/null ; then
    echo "Docker is not available!"
    exit 1
  fi
}

# Parse the arguments, given to the script by the caller.
# Not defined configuration values stay with their default values.
# A not known argument leads to an exit with status code 1.
#
# Arguments:
#   $1 - all arguments by the caller
#
function parseArguments {
  if [[ ${#ARG_VEC[@]} < 2 ]] ; then
    echo "Missing arguments"
    exit 1
  fi

  for (( i=0; i<${#ARG_VEC[@]}; i++ )) ; do
    arg="${ARG_VEC[i]}"
    nextIndex=$((i + 1))

    # Define the role for the client.
    if [[ $arg == --role ]] || [[ $arg == -r ]] ; then
      ROLE="${ARG_VEC[$nextIndex]}"
      checkRoleArgument # Make sure to have a valid role.
      i=$nextIndex

    # Define the node-key to bind.
    elif [[ $arg == --node-key ]] || [[ $arg == -nk ]] ; then
      # Take the next argument as the address and jump other it.
      NODE_KEY="${ARG_VEC[$nextIndex]}"
      i=$nextIndex

    # A not known argument.
    else
      echo Unkown argument: $arg
      exit 1
    fi
  done
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

# Initial preparations for the node.
# This will pull the images, create necessary directories and create an account.
# The user will be requested to type in the password again, as well as insert the generated address.
# Both will be stored for later (re)use.
#
function setup {
  echo -e "\nSetup node..."

  # Pull the Docker images.
  echo -e "\nPull the Docker images..."
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_PARITY

  if [[ $role == validator ]] ; then
    echo -e "\nPull the Docker images..."
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_APP
  fi

  # Create directories.
  mkdir -p $DATABASE_DIR
  mkdir -p $CONFIG_DIR

  if [[ $ROLE != bootnode && $ROLE != explorer ]] ; then
    # Get password and store it.
    if [[ ! -f "$PASSWORD_FILE" ]] ; then
      while [ -z "$PASSWORD" ] ; do
        echo -en "\nPlease insert a password.\nThe password will be used to encrypt your private key. The password will additionally be stored in plaintext in $PASSWORD_FILE, so that you do not have to enter it again.\n"
        while true; do
          read -s -p "Password: " PASSWORD
          echo
          read -s -p "Password (again): " PASSWORD2
          echo
          [ "$PASSWORD" = "$PASSWORD2" ] && break
          echo "Passwords do not match, please try again"
        done
      done

      echo "$PASSWORD" > $PASSWORD_FILE
    else
      PASSWORD=$(<$PASSWORD_FILE)
    fi

    # Create a new account if not already done.
    if [[ ! -d "$CONFIG_DIR/keys" ]] ; then
      echo -e "\nGenerate a new account..."
      ADDRESS=$(yes $PASSWORD | \
          $PERMISSION_PREFIX docker run \
        --interactive --rm \
        --volume $CONFIG_DIR:/config/custom \
        $DOCKER_IMAGE_PARITY \
        --parity-args account new |\
        grep -o "0x.*")
      echo -en "Your new address is $ADDRESS"
    fi

    # Get address and store it.
    if [[ ! -f "$ADDRESS_FILE" ]] ; then
      while [ -z "$ADDRESS" ] ; do
        echo -en "\nPlease insert/copy the address of the previously generated address of the account. It should look like '0x84adaf5fd30843eba497ae8022cac42b19a572bb':"
        read ADDRESS
      done

      echo "$ADDRESS" > $ADDRESS_FILE
    fi
  else
    if [[ -z "$NODE_KEY" ]] ; then
      echo "Missing node-key for bootnode"
      exit 1
    fi
    echo Running bootnode - no need to create account
  fi
}

# Start of the Parity node within its Docker container.
# It checks if the container is already running and do nothing, is stopped and restart it or create a new one.
# This reads in the stored address first.
# The whole container setup plus arguments will be handled automatically.
#
function startNode {
  # Check if container is already running.
  if [[ $($PERMISSION_PREFIX docker ps) == *"$DOCKER_CONTAINER_PARITY"* ]] ; then
    echo -e "\nThe Parity client is already running as container with name '$DOCKER_CONTAINER_PARITY', stopping it..."
    $PERMISSION_PREFIX docker stop $DOCKER_CONTAINER_PARITY
  fi

  # Check if the container does already exist and restart it.
  if [[ $($PERMISSION_PREFIX docker ps -a) == *"$DOCKER_CONTAINER_PARITY"* ]] ; then
    echo -e "\nThe Parity container already exists, deleting it..."
    $PERMISSION_PREFIX docker rm $DOCKER_CONTAINER_PARITY
  fi

  if [[ $ROLE == "validator" ]] ; then
    # Check if container is already running.
    if [[ $($PERMISSION_PREFIX docker ps) == *"$DOCKER_CONTAINER_APP"* ]] ; then
      echo -e "\nThe validator app is already running as container with name '$DOCKER_CONTAINER_APP', stopping it..."
      $PERMISSION_PREFIX docker stop $DOCKER_CONTAINER_APP
    fi

    # Check if the container does already exist and restart it.
    if [[ $($PERMISSION_PREFIX docker ps -a) == *"$DOCKER_CONTAINER_APP"* ]] ; then
      echo -e "\nThe validator app already exists, deleting it..."
      $PERMISSION_PREFIX docker rm $DOCKER_CONTAINER_APP
    fi
  fi


  # Create and start a new container.
  echo -e "\nStart as ${ROLE}..."

  case $ROLE in
    "bootnode")
      ## Start Parity container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        --detach \
        --name $DOCKER_CONTAINER_PARITY \
        --volume $DATABASE_DIR:/data \
        --volume $CONFIG_DIR:/config/custom \
        -p 30303:30300 \
        -p 8545:8545 \
        -p 8546:8546 \
        --restart=on-failure \
        $DOCKER_IMAGE_PARITY \
        --role bootnode \
        --parity-args --node-key $NODE_KEY
      ;;

    "validator")
      ## Read in the stored address file.
      local address=$(cat $ADDRESS_FILE)

      ## Start Parity container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        --detach \
        --name $DOCKER_CONTAINER_PARITY \
        --volume $DATABASE_DIR:/data \
        --volume $CONFIG_DIR:/config/custom \
        -p 30303:30300 \
        --restart=on-failure \
        $DOCKER_IMAGE_PARITY \
        --role validator \
        --address $address

      ## Start App container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        --detach \
        --name $DOCKER_CONTAINER_APP \
        --volume $CONFIG_DIR:/config \
        --restart=on-failure \
        $DOCKER_IMAGE_APP
      ;;

    "explorer")
      ## Start Parity container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        --detach \
        --name $DOCKER_CONTAINER_PARITY \
        --volume $DATABASE_DIR:/data \
        --volume $CONFIG_DIR:/config/custom \
        -p 30303:30300 \
        -p 8545:8545 \
        -p 8546:8546 \
        --restart=on-failure \
        $DOCKER_IMAGE_PARITY \
        --role explorer \
        --parity-args --node-key $NODE_KEY
      ;;
  esac

  echo -e "\nParity node as started and is running in background!"
}


# Getting Started
sanityChecks
parseArguments
setup
startNode