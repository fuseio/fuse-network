#!/bin/bash

set -e

OLDIFS=$IFS

QUICKSTART_VERSION="1.0.0"

#set this to true to allow for hardcoded versioning for debugging
OVERRIDE_VERSION_FILE=false
VERSION_FILE="https://raw.githubusercontent.com/fuseio/fuse-network/master/Version"
VERSION_FILE_LEGACY="https://raw.githubusercontent.com/fuseio/fuse-network/master/Version_legacy"
DOCKER_IMAGE_ORACLE_VERSION="3.0.0"
DOCKER_IMAGE_FUSE_APP_VERSION="1.0.0"
DOCKER_IMAGE_FUSE_PARITY_VERSION="1.0.0"
DOCKER_IMAGE_NET_STATS_VERSION="1.0.0"

ENV_FILE=".env"
DOCKER_IMAGE_PARITY_REPO="fusenet/node"
DOCKER_CONTAINER_PARITY="fusenet"
DOCKER_IMAGE_APP_REPO="fusenet/validator-app"
DOCKER_CONTAINER_APP="fuseapp"
DOCKER_IMAGE_NETSTAT_REPO="fusenet/netstat"
DOCKER_CONTAINER_NETSTAT="fusenetstat"
DOCKER_COMPOSE_ORACLE="https://raw.githubusercontent.com/fuseio/fuse-bridge/master/native-to-erc20/oracle/docker-compose.keystore.yml"
DOCKER_IMAGE_ORACLE_REPO="fusenet/native-to-erc20-oracle"
DOCKER_CONTAINER_ORACLE="fuseoracle"
DOCKER_LOG_OPTS="--log-opt max-size=10m --log-opt max-file=25 --log-opt compress=true"
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
PLATFORM_VARIENT=""
REQUIRED_DRIVE_SPACE_MB=15360
REQUIRED_RAM_MB=1800
DEFAULT_GAS_ORACLE="https:\/\/ethgasstation.info\/json\/ethgasAPI.json"

PARITY_SNAPSHOT="https://node-snapshot.s3.eu-central-1.amazonaws.com/db.tar.gz"
OE_SNAPSHOT="https://node-snapshot-oe.s3.eu-central-1.amazonaws.com/db.tar.gz"
BOOTNODE_FILE_FUSE="https://raw.githubusercontent.com/fuseio/fuse-network/master/config/bootnodes.txt"
BOOTNODE_FILE_SPARK="https://raw.githubusercontent.com/fuseio/fuse-network/master/config/spark/bootnodes.txt"

SNAPSHOT_NODE="$OE_SNAPSHOT"


WARNINGS=()
INFOS=()

# grab the contents of the env file and export them as env variables. 
# Set IFS to be a "universal" carriage return to avoid issues with spaces in variables.
IFS='
'
export $(grep -v '^#' "$ENV_FILE" | xargs -0)
# reset back to the OLD IFS
IFS=$OLDIFS

# If VAL_NAME or PERMISSION_PREFIX haven't been set and are still "" then make them blank
PERMISSION_PREFIX="${PERMISSION_PREFIX//\"}"
VAL_NAME="${VAL_NAME//\"}"

declare -a VALID_ROLE_LIST=(
  bootnode
  node
  validator
  explorer
  bridge-validator
)

function displayErrorAndExit {
  local arg1=$1
  if [[ $arg1 != "" ]];
  then
    echo "$(tput setaf 1)ERROR: $arg1$(tput sgr 0)"
  else
    echo "${FUNCNAME[0]} No Argument supplied"
  fi
  
  exit 1
}

function install_docker {
  echo -e "\nInstalling docker..."
  if [ $PLATFORM_VARIENT == "Ubuntu" ]; then
    $PERMISSION_PREFIX apt-get update

    $PERMISSION_PREFIX apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common

    curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | $PERMISSION_PREFIX apt-key add -

    $PERMISSION_PREFIX add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"

    $PERMISSION_PREFIX apt-get update

    $PERMISSION_PREFIX apt-get install -y docker-ce docker-ce-cli containerd.io
  elif [ $PLATFORM_VARIENT == "Debian" ]; then
    $PERMISSION_PREFIX apt update
    
    $PERMISSION_PREFIX apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common
    
    curl -fsSL https://download.docker.com/linux/debian/gpg | $PERMISSION_PREFIX apt-key add -
    
    $PERMISSION_PREFIX add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

    $PERMISSION_PREFIX apt update
    apt-cache policy docker-ce
    $PERMISSION_PREFIX apt install docker-ce docker-ce-cli containerd.io
  else
    displayErrorAndExit "UNKNOWN OS please install docker"
  fi
}

function install_docker-compose {
  echo -e "\nInstalling docker-compose..."

  $PERMISSION_PREFIX curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  $PERMISSION_PREFIX chmod +x /usr/local/bin/docker-compose

  $PERMISSION_PREFIX ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
}

function setPlatform {

  case "$(uname -s)" in

     Darwin)
       echo -e '\nRunning on Mac OS X'
       PLATFORM="MAC"
       ;;

     Linux)
       echo -e '\nRunning on Linux'
       PLATFORM="LINUX"
       PLATFORM_VARIENT=$(lsb_release -si)
       echo "Linux varient $PLATFORM_VARIENT"
       ;;

     CYGWIN*|MINGW32*|MSYS*|MINGW*)
       echo -e '\nRunning on Windows'
       PLATFORM="WINDOWS"
       ;;
     *)
       displayErrorAndExit "UNKNOWN OS exiting the script here"
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
          displayErrorAndExit "Could not pull mainnet block please check your foreign RPC config"
  fi

  if [[ "$FUSEBLOCK" == 0 ]]; then
          echo $(curl -s --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST $HOME_RPC_URL)
          displayErrorAndExit "Could not pull fuse block please check your fuse RPC config"
  fi

  echo "ETH BLOCK = $ETHBLOCK"
  echo "FUSE BLOCK = $FUSEBLOCK"

  #Open the env file and replace the exsisting block numbers with the new ones. 
  #NOTE: this assumes that the env file only contains one line for HOME/FOREIGN_START_BLOCK
  sed -i "s/^HOME_START_BLOCK.*/HOME_START_BLOCK=${FUSEBLOCK}/" "$ENV_FILE"
  sed -i "s/^FOREIGN_START_BLOCK.*/FOREIGN_START_BLOCK=${ETHBLOCK}/" "$ENV_FILE"
}

function checkEthGasAPI {
  resetOracle=false

  if [ -z "$FOREIGN_GAS_PRICE_ORACLE_URL" ] ; then
    WARNINGS+=("No eth gas station api set please update your env file to include FOREIGN_GAS_PRICE_ORACLE_URL which should set an ethgasstation endpoint see https://data.defipulse.com/ for more details")
  else
    if [[ "$FOREIGN_GAS_PRICE_ORACLE_URL" == *"https://data-api.defipulse.com/api/v1/egs/api/ethgasAPI.json?api-key="* ]]; then
      status_code=$(curl --write-out %{http_code} --silent --output /dev/null "$FOREIGN_GAS_PRICE_ORACLE_URL")

      if [[ "$status_code" == 200 ]] ; then
        echo "Positive response from gas oracle"
      else
        WARNINGS+=("trying to grab data from $FOREIGN_GAS_PRICE_ORACLE_URL is giving errors, using the default oracle")
        resetOracle=true
      fi
    else
      WARNINGS+=("FOREIGN_GAS_PRICE_ORACLE_URL Does not match ethgasstation endpoint see https://data.defipulse.com/ for more details, using the default oracle, recommend to create your own!")
      resetOracle=true
    fi

    if [ "$resetOracle" = true ] ; then
      echo "Reset FOREIGN_GAS_PRICE_ORACLE_URL back to default"
      sed -i "s/^FOREIGN_GAS_PRICE_ORACLE_URL.*/FOREIGN_GAS_PRICE_ORACLE_URL=$DEFAULT_GAS_ORACLE/" "$ENV_FILE"
    fi
  fi
}

function checkDiskSpace {
  if [ $PLATFORM == "LINUX" ]; then
    mountedDrive=$(df --output=target quickstart.sh | tail -n1)
    totalDriveSpaceBytes=$(df -k --output=size "$mountedDrive" | tail -n1)
    totalDriveSpaceMB=$(( totalDriveSpaceBytes / 1024 ))
    if [ "$totalDriveSpaceMB" -lt "$REQUIRED_DRIVE_SPACE_MB" ]; then
      displayErrorAndExit "Not enoguh total drive space! you have $totalDriveSpaceMB MB you require at least $REQUIRED_DRIVE_SPACE_MB MB to be a validator"
    fi
  fi
}

function checkAmountOfRam {
  if [ $PLATFORM == "LINUX" ]; then
    totalMemoryBytes=$(free|awk '/^Mem:/{print $2}')
    totalMemoryMB=$(( totalMemoryBytes / 1024 ))
    if [ "$totalMemoryMB" -lt "$REQUIRED_RAM_MB" ]; then
      displayErrorAndExit "Not enough total system memory! you have $totalMemoryMB MB you require at least $REQUIRED_RAM_MB MB to be a validator"
    fi
  fi
}

function sanityChecks {
  echo -e "\nSanity checks..."

  checkDiskSpace
  checkAmountOfRam

  # Check if docker is ready to use.
  if [[ "$(command -v docker)" && "$(which docker)" ]]; then 
    echo "docker already installed"
  else    
    echo "docker is not available!"
    if [ $PLATFORM == "LINUX" ]; then
      install_docker
    else            
      exit 1
    fi
  fi

  # Check if docker-compose is ready to use.
  if [[ "$(command -v docker-compose)" && "$(which docker-compose)" ]]; then  
    echo "docker-compose already installed"
  else
    echo "docker-compose is not available!"
    if [ $PLATFORM == "LINUX" ]; then
      install_docker-compose
    else
      exit 1
    fi
  fi

  # Check if .env file exists.
  if [[ ! -f "$ENV_FILE" ]] ; then
    displayErrorAndExit "$ENV_FILE does not exist!"
  fi
}

function parseArguments {
  echo -e "\nParse arguments..."

  # Check if ROLE arg exists.
  if ! [[ "$ROLE" ]] ; then
    displayErrorAndExit "Missing ROLE argument!"
  fi

  checkRoleArgument

  if [[ $ROLE != validator ]] && [[ $ROLE != bridge-validator ]]; then
    if ! [[ "$NODE_KEY" ]] ; then
      displayErrorAndExit "Missing NODE_KEY argument!"
    fi
    
    if [[ "$NODE_KEY" == "<your_node_key>" ]]; then
      displayErrorAndExit "NODE_KEY is still set to default update it in the env file"
    fi
  fi
  
  if ! [ -z "$TESTNET" ] ; then
    if [[ $TESTNET == true ]] ; then
      if [[ $ROLE == bridge-validator ]] ; then
        displayErrorAndExit "bridge-validators not supported on Spark"
      fi
      VERSION_FILE="https://raw.githubusercontent.com/fuseio/fuse-network/master/Version_testNet"
      DOCKER_IMAGE_PARITY_REPO="fusenet/spark-node"
      DOCKER_IMAGE_NETSTAT_REPO="fusenet/spark-netstat"
      DOCKER_IMAGE_APP_REPO="fusenet/spark-validator-app"
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
  displayErrorAndExit "The defined role ('$ROLE') is invalid.\nPlease choose of the following: ${VALID_ROLE_LIST[@]}"
}

function pullSnapShot {
  echo -e "\nPulling snapshot..."

  if [[ $ROLE != explorer ]] ; then
    if [ -z "$CLIENT" ] ; then
      SNAPSHOT_NODE="$OE_SNAPSHOT"
    elif [ $CLIENT == "OE" ]; then
      SNAPSHOT_NODE="$OE_SNAPSHOT"
    else
      SNAPSHOT_NODE="$PARITY_SNAPSHOT"
    fi

    echo -e "clearing out old folder"
    if [[ -d "$DATABASE_DIR/FuseNetwork/db" ]] ; then
      rm -r "$DATABASE_DIR/FuseNetwork/db"
    fi
    mkdir -p "$DATABASE_DIR/FuseNetwork"
    echo -e "\nDownloading snapshot"
    wget -O db.tar.gz "$SNAPSHOT_NODE"
    echo -e "\nExtracting"
    tar -xzvf db.tar.gz -C "$DATABASE_DIR/FuseNetwork"
    echo -e "\nDeleting temp file"
    rm db.tar.gz
  else
    WARNINGS+=("snapshots are not currently present for archive nodes")
  fi
}

function setup {
  echo -e "\nSetup..."

   # Configure the NTP service before starting so all nodes in the network are synced
  echo -e "\nConfiguring and starting ntp"
  if [ $PLATFORM == "LINUX" ]; then
    if [ $PLATFORM_VARIENT == "Ubuntu" ]; then
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
    elif [ $PLATFORM_VARIENT == "Debian" ]; then
      $PERMISSION_PREFIX apt-get purge ntp
      $PERMISSION_PREFIX systemctl start systemd-timesyncd
    elif [[ $PLATFORM_VARIENT == "CentOS" ]] || [[ $PLATFORM_VARIENT == "Fedora" ]] || [[ $PLATFORM_VARIENT == "RHEL" ]] ; then
      $PERMISSION_PREFIX yum install -y ntp
      $PERMISSION_PREFIX systemctl start ntpd
      $PERMISSION_PREFIX systemctl enable ntpd
    fi
  elif [ $PLATFORM == "MAC" ]; then
    $PERMISSION_PREFIX sntp -sS 0.pool.ntp.org
  fi

  if [ "$OVERRIDE_VERSION_FILE" == false ] ; then
    echo -e "\nGrab docker Versions"
	if [ ! -z "$CLIENT" ] ; then
		if [ $CLIENT == "PARITY" ]; then
			VERSION_FILE="$VERSION_FILE_LEGACY"
		fi
	fi
    wget -O versionFile $VERSION_FILE
    export $(grep -v '^#' versionFile | xargs)
  else
    echo -e "\n Using hardcoded version Info"
  fi

  # Print versions
  echo "Oracle version = $DOCKER_IMAGE_ORACLE_VERSION"
  echo "Parity version = $DOCKER_IMAGE_FUSE_PARITY_VERSION"
  echo "Fuse app version = $DOCKER_IMAGE_FUSE_APP_VERSION"
  echo "Netstats version = $DOCKER_IMAGE_NET_STATS_VERSION"

  # Pull the docker images.
  echo -e "\nPull the docker images..."
  DOCKER_IMAGE_PARITY="$DOCKER_IMAGE_PARITY_REPO:$DOCKER_IMAGE_FUSE_PARITY_VERSION"
  DOCKER_IMAGE_NETSTAT="$DOCKER_IMAGE_NETSTAT_REPO:$DOCKER_IMAGE_NET_STATS_VERSION"
  DOCKER_IMAGE_APP="$DOCKER_IMAGE_APP_REPO:$DOCKER_IMAGE_FUSE_APP_VERSION"
  DOCKER_IMAGE_ORACLE="$DOCKER_IMAGE_ORACLE_REPO:$DOCKER_IMAGE_ORACLE_VERSION"
  
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_PARITY
  $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_NETSTAT

  if [[ $ROLE == validator ]] || [[ $ROLE == bridge-validator ]] ; then
    echo -e "\nPull additional docker images..."
    $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_APP
  fi
  
  if [[ $ROLE == bridge-validator ]] ; then
    $PERMISSION_PREFIX docker pull $DOCKER_IMAGE_ORACLE

    echo -e "\nDownload oracle docker-compose.yml"
    wget -O docker-compose.yml $DOCKER_COMPOSE_ORACLE
    
    echo -e "\nUpdating block numbers in env file"
    getAndUpdateBlockNumbers
    
    checkEthGasAPI
  fi

  # Create directories.
  mkdir -p $DATABASE_DIR
  mkdir -p $CONFIG_DIR
  if [[ $ROLE == validator ]] || [[ $ROLE == bridge-validator ]] ; then
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

  if [[ $ROLE == "validator" ]] || [[ $ROLE == bridge-validator ]] ; then
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
  
  if [[ $TESTNET != true ]] ; then
    if [ -z "$CLIENT" ] ; then
      read -p "Do you want to upgrade your Client? [Y/N] (this will cause ~30mins downtime and requires 20GB free diskspace, UPGRADE IS REQUIRED BEFORE BLOCK 14MILLION)" -n 1 -r
      echo    # (optional) move to a new line
      if [[ $REPLY =~ ^[Yy]$ ]] ; then
        if [[ $ROLE == explorer ]] ; then
        displayErrorAndExit "Explorer snapshot not present, Script is assuming a migration from parity to OE, if this is not the case please add CLIENT=OE/ CLIENT=PARITY to your .env file. To upgrade your DB please run the upgrade tool https://github.com/openethereum/3.1-db-upgrade-tool"
        fi
        echo -e "\n\n NO CLIENT SET ASSUME running parity, need to update DB\n\n"
        pullSnapShot
        echo "CLIENT=OE" >> $ENV_FILE
      else
        CLIENT="PARITY"
        #re run setup to pull Parity version
        setup
        if [[ $USE_SNAPSHOT == true ]] ; then
          pullSnapShot
        fi
      fi
    else
      if ! [ -z "$USE_SNAPSHOT" ] ; then
        if [[ $USE_SNAPSHOT == true ]] ; then
          pullSnapShot
        fi
      fi
    fi
  fi

  # Create and start a new container.
  echo -e "\nStarting as ${ROLE}..."
  
  # Pull bootnodes
  if [[ $TESTNET != true ]] ; then
    wget -O bootnodeFile $BOOTNODE_FILE_FUSE
  else
    wget -O bootnodeFile $BOOTNODE_FILE_SPARK
  fi
  
  BOOTNODES=""
  
  while IFS= read -r line
  do
    BOOTNODES+="${line},"
  done < "bootnodeFile"
  
  #remove the trailing comma
  BOOTNODES=${BOOTNODES::-1}
  
  echo "Bootnodes = $BOOTNODES"

  case $ROLE in
    "bootnode")
      INSTANCE_NAME=$NODE_KEY
      
      key=$(printf "$NODE_KEY" | openssl dgst -sha3-256 | grep -o "\w* \w*" )
      key="0x${key:1}"
      echo "Your node key is = $key"

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
        --parity-args --no-warp --node-key $key --max-pending-peers 128 --max-peers 128 --min-peers 80  --bootnodes=$BOOTNODES
      ;;

    "node")
      INSTANCE_NAME=$NODE_KEY

      ## parse parity config
      cpuCores=1
      if [ $PLATFORM == "LINUX" ]; then
        cpuCores=$(nproc --all)
      fi
      NUM_RPC_THREADS=$cpuCores
      NUM_HTTP_THREADS=$(( 4*cpuCores ))
      if [ -z "$NUMBER_OF_RPC_THREADS" ] ; then
        echo "using default RPC thread values"
      else
        NUM_RPC_THREADS=$NUMBER_OF_RPC_THREADS
        echo "reading RPC threads from env file $NUM_RPC_THREADS"
      fi

      if [ -z "$NUMBER_OF_HTTP_CONNECTIONS_THREADS" ] ; then
        echo "using default http thread values"
      else
        NUM_HTTP_THREADS=$NUMBER_OF_HTTP_CONNECTIONS_THREADS
        echo "reading HTTP connection threads from env file $NUM_HTTP_THREADS"
      fi

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
        --parity-args --no-warp --node-key $NODE_KEY --jsonrpc-threads $NUM_RPC_THREADS --jsonrpc-server-threads $NUM_HTTP_THREADS --bootnodes=$BOOTNODES
      ;;

    "validator")
      ## Read in the stored address file.
      local address=$(cat $ADDRESS_FILE)

      INSTANCE_NAME=$address
      if [ -z "$VAL_NAME" ] ; then
        INFOS+=("using the address as the netstats name to update this pull the latest env file and set the VAL_NAME variable")
      else
        echo "setting netstats name to $VAL_NAME"
        INSTANCE_NAME="${VAL_NAME}_${address}"
      fi


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
      ;;
      
     "bridge-validator")
       ## Read in the stored address file.
       local address=$(cat $ADDRESS_FILE)

        INSTANCE_NAME=$address
        if [ -z "$VAL_NAME" ] ; then
          INFOS+=("using the address as the netstats name to update this pull the latest env file and set the VAL_NAME variable")
        else
          echo "setting netstats name to $VAL_NAME"
          INSTANCE_NAME="${VAL_NAME}_${address}"
        fi


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
          --parity-args --no-warp --bootnodes=$BOOTNODES

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
        --parity-args --node-key $NODE_KEY --bootnodes=$BOOTNODES
      ;;
  esac

  ## Start netstat container with all necessary arguments.
  if [[ $ROLE == bridge-validator ]] ; then
    $PERMISSION_PREFIX docker run \
      $DOCKER_LOG_OPTS \
      --detach \
      --name $DOCKER_CONTAINER_NETSTAT \
      --net=container:$DOCKER_CONTAINER_PARITY \
      --restart=always \
      --memory="250m" \
      $DOCKER_IMAGE_NETSTAT \
      --instance-name "$INSTANCE_NAME" \
      --bridge-version "$DOCKER_IMAGE_ORACLE_VERSION" \
      --role "$ROLE" \
      --parity-version "$DOCKER_IMAGE_FUSE_PARITY_VERSION" \
      --fuseapp-version "$DOCKER_IMAGE_FUSE_APP_VERSION" \
      --netstats-version "$DOCKER_IMAGE_NET_STATS_VERSION"
  else
    $PERMISSION_PREFIX docker run \
      $DOCKER_LOG_OPTS \
      --detach \
      --name $DOCKER_CONTAINER_NETSTAT \
      --net=container:$DOCKER_CONTAINER_PARITY \
      --restart=always \
      --memory="250m" \
      $DOCKER_IMAGE_NETSTAT \
      --instance-name "$INSTANCE_NAME" \
      --role "$ROLE" \
      --parity-version "$DOCKER_IMAGE_FUSE_PARITY_VERSION" \
      --fuseapp-version "$DOCKER_IMAGE_FUSE_APP_VERSION" \
      --netstats-version "$DOCKER_IMAGE_NET_STATS_VERSION"
  fi

  echo -e "\nContainers started and running in background!"
}

function displayWarning {
  for info in "${INFOS[@]}"
  do
    echo "$(tput setaf 3)INFO: $info$(tput sgr 0)"
  done
  
  for warning in "${WARNINGS[@]}"
  do
    echo "$(tput setaf 1)WARN: $warning$(tput sgr 0)"
  done 
}


# Go :)
setPlatform
sanityChecks
parseArguments
setup
run
displayWarning
IFS=$OLDIFS