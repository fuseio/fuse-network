#!/bin/bash

set -e

# Variables
DOCKER_IMAGE_PARITY="fusenetwork/fusenet"
DOCKER_IMAGE_WATCHTOWER="v2tec/watchtower"
DOCKER_CONTAINER_PARITY="fusnet"
DOCKER_CONTAINER_WATCHTOWER="watchtower-testnet"

PERMISSION_PREFIX=""
BASE_DIR=$(pwd)/fusenet
DATABASE_DIR=$BASE_DIR/database
CONFIG_DIR=$BASE_DIR/config
ENODE_DIR=$BASE_DIR/enode
PASSWORD_FILE=$CONFIG_DIR/pass.pwd
PASSWORD=""
ADDRESS_FILE=$CONFIG_DIR/address
ADDRESS=""

# Arguments
ARG_SETUP=false


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

  # Check if user is part of the docker group.
  if [[ $(getent group docker) != *"$USER"* ]] ; then
    # Request the user for root permissions for specific commands.
    PERMISSION_PREFIX="sudo"
  fi
}


# Initial preparations for the validator node.
# This will pull the images, create necessary directories and create an account.
# The user will be requested to type in the password again, as well as insert the generated address.
# Both will be stored for later (re)use.
#
function setup {
  echo -e "\nSetup validator node..."

  # Pull the Docker images.
  echo -e "\nPull the Docker images..."
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_PARITY
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_WATCHTOWER

  # Create directories.
  mkdir -p $DATABASE_DIR
  mkdir -p $CONFIG_DIR
  mkdir -p $ENODE_DIR


  # Get password and store it.
  if [[ ! -f "$PASSWORD_FILE" ]] ; then
    while [ -z "$PASSWORD" ] ; do
      echo -en "\nPlease insert a password.\nThe password will be used to encrypt your validator private key. The password will additionally be stored in plaintext in $PASSWORD_FILE, so that you do not have to enter it again.\n"
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
    echo -en "Your new validator address is $ADDRESS"
  fi

  # Get address and store it.
  if [[ ! -f "$ADDRESS_FILE" ]] ; then
    while [ -z "$ADDRESS" ] ; do
      echo -en "\nPlease insert/copy the address of the previously generated address of the account. It should look like '0x84adaf5fd30843eba497ae8022cac42b19a572bb':"
      read ADDRESS
    done

    echo "$ADDRESS" > $ADDRESS_FILE
  fi
}


# Start the Watchtower within its Docker container.
# It checks if the container is already running and do nothing, is stopped and restart it or create a new one.
#
function startWatchtower {
  # Check if container is already running.
  if [[ $($PERMISSION_PREFIX docker ps) == *"$DOCKER_CONTAINER_WATCHTOWER"* ]] ; then
    echo -e "\nThe Watchtower client is already running as container, stopping it..."
    $PERMISSION_PREFIX docker stop $DOCKER_CONTAINER_WATCHTOWER
  fi
  # Check if the container does already exist and restart it.
  if [[ $($PERMISSION_PREFIX docker ps -a) == *"$DOCKER_CONTAINER_WATCHTOWER"* ]] ; then
    echo -e "\nThe Watchtower container already exists, deleting it..."
    $PERMISSION_PREFIX docker rm $DOCKER_CONTAINER_WATCHTOWER
  fi
  # Pull and start the container
  echo -e "\nStart the Watchtower client..."
  $PERMISSION_PREFIX docker run \
    --detach \
    --name $DOCKER_CONTAINER_WATCHTOWER \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    $DOCKER_IMAGE_WATCHTOWER
}


# Start of the validator Parity node within its Docker container.
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


  # Create and start a new container.
  echo -e "\nStart the Parity client as validator..."

  ## Read in the stored address file.
  local address=$(cat $ADDRESS_FILE)

  ## Start Parity container with all necessary arguments.
  $PERMISSION_PREFIX docker run \
    --detach \
    --name $DOCKER_CONTAINER_PARITY \
    --volume $DATABASE_DIR:/data \
    --volume $CONFIG_DIR:/config/custom \
    --volume $ENODE_DIR:/config/network \
    -p 30300:30300 \
    -p 30300:30300/udp \
    --restart=on-failure \
    $DOCKER_IMAGE_PARITY \
    --role validator \
    --address $address

  echo -e "\nParity node as started and is running in background!"
}



# Getting Started
sanityChecks
setup
startWatchtower
startNode