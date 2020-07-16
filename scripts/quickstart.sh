#!/bin/bash

set -e

OLDIFS=$IFS

ENV_FILE=".env"
DOCKER_IMAGE_PARITY="fusenet/node"
DOCKER_CONTAINER_PARITY="fusenet"
DOCKER_IMAGE_APP="fusenet/validator-app"
DOCKER_CONTAINER_APP="fuseapp"
DOCKER_IMAGE_NETSTAT="fusenet/netstat"
DOCKER_CONTAINER_NETSTAT="fusenetstat"
DOCKER_COMPOSE_ORACLE="https://raw.githubusercontent.com/fuseio/fuse-bridge/master/native-to-erc20/oracle/docker-compose.keystore.yml"
DOCKER_IMAGE_ORACLE_VERSION="2.0.4"
DOCKER_IMAGE_ORACLE="fusenet/native-to-erc20-oracle:$DOCKER_IMAGE_ORACLE_VERSION"
DOCKER_CONTAINER_ORACLE="fuseoracle"
DOCKER_LOG_OPTS="--log-opt max-size=10m --log-opt max-file=100 --log-opt compress=true"
BASE_DIR=$(pwd)/fusenet
DATABASE_DIR=$BASE_DIR/database
CONFIG_DIR=$BASE_DIR/config
PASSWORD_FILE=$CONFIG_DIR/pass.pwd
PASSWORD=""
ADDRESS_FILE=$CONFIG_DIR/address
ADDRESS=""
NODE_KEY=""
INSTANCE_NAME=""
PLATFORM=""
export $(grep -v '^#' "$ENV_FILE" | xargs)

declare -a VALID_ROLE_LIST=(
  bootnode
  node
  validator
  explorer
)

function setPlatform {

  case "$(uname -s)" in

     Darwin)
       echo -e '\nRunning on Mac OS X'
       PLATFORM="MAC"
       ;;

     Linux)
       echo -e '\nRunning on Linux'
       PLATFORM="LINUX"
       ;;

     CYGWIN*|MINGW32*|MSYS*|MINGW*)
       echo -e '\nRunning on Windows'
       PLATFORM="WINDOWS"
       ;;
     *)
       echo 'UNKNOWN OS exiting the script here'
       exit 1
       ;;
  esac
}

function getAndUpdateBlockNumbers {
  
  ETHBLOCK=0
  FUSEBLOCK=0
  
  echo "Grabbing current Fuse block number"
  FUSEBLOCK=$((`curl -s --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST $HOME_RPC_URL | { grep -o "\w*0x\w*" || true; }`))

 
  echo "Grabbing current Eth block number"
  ETHBLOCK=$((`curl -s --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST $FOREIGN_RPC_URL | { grep -o "\w*0x\w*" || true; }`))

  if [[ "$ETHBLOCK" == 0 ]]; then
	  echo $(curl -s --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST $FOREIGN_RPC_URL$ADDPORT)
	  echo "Could not pull mainnet block please check your foreign RPC config"
	  exit 1
  fi

  if [[ "$FUSEBLOCK" == 0 ]]; then
	  echo $(curl -s --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST $HOME_RPC_URL)
	  echo "Could not pull fuse block please check your fuse RPC config"
          exit 1
  fi

  echo "ETH BLOCK = $ETHBLOCK"
  echo "FUSE BLOCK = $FUSEBLOCK"

  #Open the env file and replace the exsisting block numbers with the new ones. 
  #NOTE: this assumes that the env file only contains one line for HOME/FOREIGN_START_BLOCK
  sed -i "s/^HOME_START_BLOCK.*/HOME_START_BLOCK=${FUSEBLOCK}/" "$ENV_FILE"
  sed -i "s/^FOREIGN_START_BLOCK.*/FOREIGN_START_BLOCK=${ETHBLOCK}/" "$ENV_FILE"
}

function sanityChecks {
  echo -e "\nSanity checks..."

  # Check if docker is ready to use.
  if ! command -v docker>/dev/null ; then
    echo "docker is not available!"
    exit 1
  fi

  # Check if docker-compose is ready to use.
  if ! command -v docker-compose>/dev/null ; then
    echo "docker-compose is not available!"
    exit 1
  fi

  # Check if .env file exists.
  if [[ ! -f "$ENV_FILE" ]] ; then
    echo "$ENV_FILE does not exist!"
    exit 1
  fi
}

function parseArguments {
  echo -e "\nParse arguments..."

  export $(grep -v '^#' "$ENV_FILE" | xargs)

  # Check if ROLE arg exists.
  if ! [[ "$ROLE" ]] ; then
    echo "Missing ROLE argument!"
    exit 1
  fi

  checkRoleArgument

  if [[ $ROLE != validator ]] ; then
    if ! [[ "$NODE_KEY" ]] ; then
      echo "Missing NODE_KEY argument!"
      exit 1
    fi
  fi

  if [[ $ROLE == bootnode ]] ; then
    if ! [[ "$BOOTNODES" ]] ; then
      echo "Warning! trying to run a bootnode without BOOTNODES argument!"
    fi
  fi
}

function checkRoleArgument {
  echo -e "\nCheck role argument..."

  # Check each known role and end if it match.
  for i in "${VALID_ROLE_LIST[@]}" ; do
    [[ $i == $ROLE ]] && return
  done

  # Error report to the user with the correct usage.
  echo "The defined role ('$ROLE') is invalid."
  echo "Please choose of the following: ${VALID_ROLE_LIST[@]}"
  exit 1
}

function setup {
  echo -e "\nSetup..."

   # Configure the NTP service before starting so all nodes in the network are synced
  echo -e "\nConfiguring and starting ntp"
  if [ $PLATFORM == "LINUX" ]; then
    $PERMISSION_PREFIX apt-get install -y ntp
    $PERMISSION_PREFIX apt-get install -y ntpdate
    $PERMISSION_PREFIX service ntp stop
    $PERMISSION_PREFIX ntpdate 0.pool.ntp.org
    $PERMISSION_PREFIX service ntp start
    

    echo -e "\nDisable Transparant Huge Pages (THP)"
    #check the version since hugepages isn't avaliable in U20.04
    VER=$(lsb_release -sr)
    VERSION_MAIN=$(echo "$VER" | cut -f1 -d".")
    if (( $VERSION_MAIN < 20 )) ; then
	$PERMISSION_PREFIX apt-get install -y hugepages
    else
	$PERMISSION_PREFIX apt-get install -y libhugetlbfs-bin
    fi

    $PERMISSION_PREFIX hugeadm --thp-never
    
    echo -e "\nEnable Overcommit Memory"
    $PERMISSION_PREFIX  sysctl vm.overcommit_memory=1
  elif [ $PLATFORM == "MAC" ]; then
    $PERMISSION_PREFIX sntp -sS 0.pool.ntp.org
  fi

  # Pull the docker images.
  echo -e "\nPull the docker images..."
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_PARITY
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_NETSTAT

  if [[ $ROLE == validator ]] ; then
    echo -e "\nPull additional docker images..."
    $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_APP
    $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_ORACLE

    echo -e "\nDownload oracle docker-compose.yml"
    wget -O docker-compose.yml $DOCKER_COMPOSE_ORACLE
  fi

  # Create directories.
  mkdir -p $DATABASE_DIR
  mkdir -p $CONFIG_DIR
  if [[ $ROLE == validator ]] ; then
    # Get password and store it.
    if [[ ! -f "$PASSWORD_FILE" ]] ; then
	IFS=$'\n'
      while [ -z "$PASSWORD" ] ; do
        echo -en "\nPlease insert a password.\nThe password will be used to encrypt your private key. The password will additionally be stored in plaintext in $PASSWORD_FILE, so that you do not have to enter it again.\n"
        while true; do
          read -s -r -p "Password: " PASSWORD
          echo
          read -s -r -p "Password (again): " PASSWORD2
          echo
          [ "$PASSWORD" = "$PASSWORD2" ] && break
          echo "Passwords do not match, please try again"
        done
      done
      IFS=$OLDIFS

      echo "$PASSWORD" > $PASSWORD_FILE
    else
      PASSWORD=$(<$PASSWORD_FILE)
    fi

    export VALIDATOR_KEYSTORE_PASSWORD=$PASSWORD
    count=$(cat $ENV_FILE | grep "VALIDATOR_KEYSTORE_PASSWORD" | wc -l)
    if [ $count -lt 1 ]; then
      echo "VALIDATOR_KEYSTORE_PASSWORD=$PASSWORD" >> $ENV_FILE
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
      VALIDATOR_ADDRESS=$ADDRESS
      echo -en "Your new address is $ADDRESS"
    fi

    # Get address and store it.
    if [[ ! -f "$ADDRESS_FILE" ]] ; then
      while [ -z "$ADDRESS" ] ; do
        echo -en "\nPlease insert/copy the address of the previously generated address of the account. It should look like '0x84adaf5fd30843eba497ae8022cac42b19a572bb':"
        read ADDRESS
      done
      echo "$ADDRESS" > $ADDRESS_FILE
    else
      VALIDATOR_ADDRESS=$(<$ADDRESS_FILE)
    fi

    export VALIDATOR_KEYSTORE_DIR=$CONFIG_DIR/keys/FuseNetwork
    count=$(cat $ENV_FILE | grep "VALIDATOR_KEYSTORE_DIR" | wc -l)
    if [ $count -lt 1 ]; then
      echo "VALIDATOR_KEYSTORE_DIR=$CONFIG_DIR/keys/FuseNetwork" >> $ENV_FILE
    fi
  else
    echo Running node - no need to create account
  fi

  echo -e "\nUpdating block numbers in env file"
  getAndUpdateBlockNumbers
}

function run {
  echo -e "\nRun..."

  # Check if the parity container is already running.
  if [[ $($PERMISSION_PREFIX docker ps) == *"$DOCKER_CONTAINER_PARITY"* ]] ; then
    echo -e "\nThe parity client is already running as container with name '$DOCKER_CONTAINER_PARITY', stopping it..."
    $PERMISSION_PREFIX docker stop $DOCKER_CONTAINER_PARITY
  fi

  # Check if the the parity container does already exist and restart it.
  if [[ $($PERMISSION_PREFIX docker ps -a) == *"$DOCKER_CONTAINER_PARITY"* ]] ; then
    echo -e "\nThe parity container already exists, deleting it..."
    $PERMISSION_PREFIX docker rm $DOCKER_CONTAINER_PARITY
  fi

  # Check if the netstat container is already running.
  if [[ $($PERMISSION_PREFIX docker ps) == *"$DOCKER_CONTAINER_NETSTAT"* ]] ; then
    echo -e "\nThe netstat client is already running as container with name '$DOCKER_CONTAINER_NETSTAT', stopping it..."
    $PERMISSION_PREFIX docker stop $DOCKER_CONTAINER_NETSTAT
  fi

  # Check if the the netstat container does already exist and restart it.
  if [[ $($PERMISSION_PREFIX docker ps -a) == *"$DOCKER_CONTAINER_NETSTAT"* ]] ; then
    echo -e "\nThe netstat container already exists, deleting it..."
    $PERMISSION_PREFIX docker rm $DOCKER_CONTAINER_NETSTAT
  fi

  if [[ $ROLE == "validator" ]] ; then
    # Check if the validator-app container is already running.
    if [[ $($PERMISSION_PREFIX docker ps) == *"$DOCKER_CONTAINER_APP"* ]] ; then
      echo -e "\nThe validator app is already running as container with name '$DOCKER_CONTAINER_APP', stopping it..."
      $PERMISSION_PREFIX docker stop $DOCKER_CONTAINER_APP
    fi

    # Check if the validator-app container does already exist and restart it.
    if [[ $($PERMISSION_PREFIX docker ps -a) == *"$DOCKER_CONTAINER_APP"* ]] ; then
      echo -e "\nThe validator app already exists, deleting it..."
      $PERMISSION_PREFIX docker rm $DOCKER_CONTAINER_APP
    fi

    # Check if the oracle container is already running.
    if [[ $($PERMISSION_PREFIX docker ps) == *"$DOCKER_CONTAINER_ORACLE"* ]] ; then
      echo -e "\nThe oracle is already running as container with name '$DOCKER_CONTAINER_ORACLE', stopping it..."
      $PERMISSION_PREFIX docker-compose down
    fi
  fi


  # Create and start a new container.
  echo -e "\nStarting as ${ROLE}..."

  case $ROLE in
    "bootnode")
      INSTANCE_NAME=$NODE_KEY

      ## Start parity container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        $DOCKER_LOG_OPTS \
        --detach \
        --name $DOCKER_CONTAINER_PARITY \
        --volume $DATABASE_DIR:/data \
        --volume $CONFIG_DIR:/config/custom \
        -p 30303:30300/tcp \
        -p 30303:30300/udp \
        -p 8545:8545 \
        -p 8546:8546 \
        --restart=always \
        $DOCKER_IMAGE_PARITY \
        --role node \
        --parity-args --no-warp --node-key $NODE_KEY --bootnodes=$BOOTNODES
      ;;

    "node")
      INSTANCE_NAME=$NODE_KEY

      ## Start parity container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        $DOCKER_LOG_OPTS \
        --detach \
        --name $DOCKER_CONTAINER_PARITY \
        --volume $DATABASE_DIR:/data \
        --volume $CONFIG_DIR:/config/custom \
        -p 30303:30300/tcp \
        -p 30303:30300/udp \
        -p 8545:8545 \
        -p 8546:8546 \
        --restart=always \
        $DOCKER_IMAGE_PARITY \
        --role node \
        --parity-args --no-warp --node-key $NODE_KEY
      ;;

    "validator")
      ## Read in the stored address file.
      local address=$(cat $ADDRESS_FILE)

      INSTANCE_NAME=$address

      ## Start parity container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        $DOCKER_LOG_OPTS \
        --detach \
        --name $DOCKER_CONTAINER_PARITY \
        --volume $DATABASE_DIR:/data \
        --volume $CONFIG_DIR:/config/custom \
        -p 30303:30300/tcp \
        -p 30303:30300/udp \
        -p 8545:8545 \
        --restart=always \
        $DOCKER_IMAGE_PARITY \
        --role validator \
        --address $address \
        --parity-args --no-warp

      ## Start validator-app container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        $DOCKER_LOG_OPTS \
        --detach \
        --name $DOCKER_CONTAINER_APP \
        --volume $CONFIG_DIR:/config \
        --restart=always \
        --memory="250m" \
        $DOCKER_IMAGE_APP

      ## Start oracle container with all necessary arguments.
      $PERMISSION_PREFIX docker-compose up \
        --build \
        -d
      ;;

    "explorer")
      INSTANCE_NAME=$NODE_KEY

      ## Start parity container with all necessary arguments.
      $PERMISSION_PREFIX docker run \
        $DOCKER_LOG_OPTS \
        --detach \
        --name $DOCKER_CONTAINER_PARITY \
        --volume $DATABASE_DIR:/data \
        --volume $CONFIG_DIR:/config/custom \
        -p 30303:30300/tcp \
        -p 30303:30300/udp \
        -p 8545:8545 \
        -p 8546:8546 \
        --restart=always \
        $DOCKER_IMAGE_PARITY \
        --role explorer \
        --parity-args --node-key $NODE_KEY
      ;;
  esac

  ## Start netstat container with all necessary arguments.
  $PERMISSION_PREFIX docker run \
    $DOCKER_LOG_OPTS \
    --detach \
    --name $DOCKER_CONTAINER_NETSTAT \
    --net=container:$DOCKER_CONTAINER_PARITY \
    --restart=always \
    --memory="250m" \
    $DOCKER_IMAGE_NETSTAT \
    --instance-name "$INSTANCE_NAME" \
    --bridge-version "$DOCKER_IMAGE_ORACLE_VERSION"

  echo -e "\nContainers started and running in background!"
}


# Go :)
setPlatform
sanityChecks
parseArguments
setup
run
IFS=$OLDIFS
