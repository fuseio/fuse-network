#!/usr/bin/env bash

# Exit when any command fail (global solution)
set -e

# IFS
OIFS=$IFS

# Quickstart script - Version
QUICKSTART_VERSION="2.0.0"

# OS (Linux / Unix based)
DISTRIBUTION_NAME=$(awk -F '[="]*' '/^NAME/ { print $2 }' </etc/os-release)
DISTRIBUTION_ID=$(awk -F '[="]*' '/^ID=/ { print $2 }' </etc/os-release)

# Required SUDO permissions
PERMISSION_PREFIX="sudo"

OVERRIDE_VERSION_FILE=false
VERSION_FILE="https://raw.githubusercontent.com/fuseio/fuse-network/master/Version"
SPARK_VERSION_FILE="https://raw.githubusercontent.com/fuseio/fuse-network/master/Version_testNet"
DOCKER_IMAGE_ORACLE_VERSION="3.0.0"
DOCKER_IMAGE_FUSE_APP_VERSION="1.0.0"
DOCKER_IMAGE_NM_CLIENT="nethermind-1.13.3-v3.0.0"
DOCKER_IMAGE_NET_STATS_VERSION="1.0.0"

# Valid role list
declare -a VALID_ROLE_LIST=(
    "node"
    "bootnode"
    "explorer"
    "validator"
)

# Valid network list
declare -a VALID_NETWORK_LIST=(
    "fuse"
    "spark"
)

# Function to display an error and exit
function display_error_and_exit {
    local arg1=$1
    if [[ $arg1 != "" ]]; then
        echo "$(tput setaf 1)ERROR: $arg1$(tput sgr 0)"
    else
        echo "${FUNCNAME[0]} No Argument supplied"
    fi

    exit 1
}

# Function to check OS
function check_os() {
    if [[ "$(uname)" == "Linux" ]]; then
        echo -e "\nYou're running script on Linux OS."
    else
        display_error_and_exit "\nYou're running script on non - Linux OS. Exit."
    fi
}

# Function to install needed tools: jq, curl
function install_tools() {
    echo -e "\nInstall needed tools...\n"
    if [[ $DISTRIBUTION_NAME == "Ubuntu" || $DISTRIBUTION_NAME == "Debian" ]]; then
        $PERMISSION_PREFIX apt-get install jq curl -y
    elif [[ $DISTRIBUTION_NAME == *"CentOS"* || $DISTRIBUTION_NAME == "Red Hat Enterprise Linux" ]]; then
        $PERMISSION_PREFIX yum install jq curl -y
    elif [[ $DISTRIBUTION_NAME == "Fedora" ]]; then
        $PERMISSION_PREFIX dnf install jq curl -y
    else
        display_error_and_exit "\nWe'd support next distributions: Ubuntu, Debian, CentOS, RHEL, Fedora. Please check out your distribution and install jq, curl tools."
    fi
}

# Function to install Docker and Docker Compose for specific Linux distribution
function install_docker() {
    echo -e "Install Docker and Docker Compose..."

    if [[ $DISTRIBUTION_NAME == "Ubuntu" || $DISTRIBUTION_NAME == "Debian" ]]; then

        $PERMISSION_PREFIX apt-get update

        $PERMISSION_PREFIX apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        $PERMISSION_PREFIX mkdir -p /etc/apt/keyrings

        curl -fsSL https://download.docker.com/linux/${DISTRIBUTION_ID}/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRIBUTION_NAME,,} \
        $(lsb_release -cs) stable" | sudo tee -a /etc/apt/sources.list.d/docker.list >/dev/null

        $PERMISSION_PREFIX apt-get update

        $PERMISSION_PREFIX apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

        echo -e "\nDocker and Docker Compose were installed for ${DISTRIBUTION_NAME}."
    elif [[ $DISTRIBUTION_NAME == *"CentOS"* || $DISTRIBUTION_NAME == "Red Hat Enterprise Linux" ]]; then

        $PERMISSION_PREFIX yum install -y yum-utils

        $PERMISSION_PREFIX yum-config-manager \
            --add-repo \
            https://download.docker.com/linux/${DISTRIBUTION_ID}/docker-ce.repo

        $PERMISSION_PREFIX yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

        $PERMISSION_PREFIX systemctl start docker

        echo -e "\nDocker and Docker Compose were installed for ${DISTRIBUTION_NAME}."
    elif [[$DISTRIBUTION_NAME == "Fedora" ]]; then

        $PERMISSION_PREFIX dnf -y install dnf-plugins-core

        $PERMISSION_PREFIX dnf config-manager \
            --add-repo \
            https://download.docker.com/linux/${DISTRIBUTION_ID}/docker-ce.repo

        $PERMISSION_PREFIX dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

        echo -e "\nDocker and Docker Compose were installed for ${DISTRIBUTION_NAME}."
    else
        display_error_and_exit "\nWe'd support next distributions: Ubuntu, Debian, CentOS, Red Hat Enterprise Linux, Fedora. Please check out your distribution and install Docker."
    fi
}

# Function to install and configure NTP for specific Linux distribution
function install_ntp() {
    echo -e "\nInstall and configure NTP (chrony)...\n"

    if [[ $DISTRIBUTION_NAME == "Ubuntu" || $DISTRIBUTION_NAME == "Debian" ]]; then
        $PERMISSION_PREFIX apt-get install chrony -y
    elif [[ $DISTRIBUTION_NAME == *"CentOS"* || $DISTRIBUTION_NAME == "Red Hat Enterprise Linux" ]]; then
        $PERMISSION_PREFIX yum install chrony -y
    elif [[ $DISTRIBUTION_NAME == "Fedora" ]]; then
        $PERMISSION_PREFIX dnf install chrony -y
    else
        display_error_and_exit "\nWe'd support next distributions: Ubuntu, Debian, Red Hat Enterprise Linux, CentOS, Fedora. Please check out your distribution and install / configure NTP."
    fi

    $PERMISSION_PREFIX systemctl stop chrony
    $PERMISSION_PREFIX chronyd -q 'server 0.europe.pool.ntp.org iburst'
    $PERMISSION_PREFIX systemctl start chrony
    $PERMISSION_PREFIX systemctl enable chrony
}

# Function to check disk space
function check_disk_space() {

    # Specify disk space treshold
    REQUIRED_DISK_SPACE_GB=100

    # We're using mount volume where is quickstart.sh file
    mounted_volume=$(df --output=target quickstart.sh | tail -n1)
    total_volume_size_mb=$(df -k --output=size "$mounted_volume" | tail -n1)
    total_volume_size_gb=$((total_volume_size_mb / 1024 / 1024))

    # Check with specified treshold
    if [ $total_volume_size_gb -lt $REQUIRED_DISK_SPACE_GB ]; then
        display_error_and_exit "\nCheck disk space.... ERROR - Not enoguh total drive space! you have $total_volume_size_gb GB you require at least $REQUIRED_DISK_SPACE_GB GB!"
    else
        echo -e "\nCheck disk space.... OK!"
    fi
}

# Function to check RAM memory space
function check_ram_memory_space() {

    # Specify RAM memory treshold
    REQUIRED_RAM_GB=8

    # Identify RAM memory amount
    total_ram_memory_size_mb=$(free -m | grep Mem: | awk '{print $2}')
    total_ram_memory_size_gb=$((total_ram_memory_size_mb / 1024))

    # Check with specified treshold
    if [ $total_ram_memory_size_gb -lt $REQUIRED_RAM_GB ]; then
        display_error_and_exit "\nCheck RAM memory space... ERROR - Not enoguh total RAM memory space! you have $total_ram_memory_size_gb GB you require at least $REQUIRED_RAM_GB GB!"
    else
        echo -e "\nCheck RAM memory space... OK!"
    fi
}

# Function to check are needed tools installed or not
function check_install_tools() {
    if [[ $(command -v jq) && $(command -v curl) ]]; then
        echo -e "\nCheck needed tools install... OK!"
    else
        echo -e "\nCheck needed tools install... ERROR - Needed tools aren't installed. Installing...\n"

        install_tools

        if [[ $(command -v jq) && $(command -v curl) ]]; then
            echo -e "\nCheck needed tools install... OK!"
        fi
    fi
}

# Function to check are Docker and Docker Compose installed or not
function check_install_docker() {
    if [[ $(command -v docker) && $(command -v docker compose) ]]; then
        echo -e "\nCheck Docker and Docker Compose install... OK!"
    else
        echo -e "\nCheck Docker and Docker Compose install... ERROR - Docker / Docker Compose aren't installed. Installing...\n"

        install_docker

        if [[ $(command -v docker) && $(command -v docker compose) ]]; then
            echo -e "\nCheck Docker and Docker Compose install... OK!"
        fi
    fi
}

# Function to check needed node arguments
function check_node_arguments() {
    if [[ ${VALID_ROLE_LIST[*]} =~ "$ROLE" ]]; then
        echo -e "\nCheck is valid role or not... OK!"
    else
        display_error_and_exit "\nCheck is valid role or not... ERROR - Invalid role - $ROLE! Please choose of the following: ${VALID_ROLE_LIST[*]}"
    fi

    if [[ ${VALID_NETWORK_LIST[*]} =~ "$NETWORK" ]]; then
        echo -e "\nCheck is valid network or not... OK!"
    else
        display_error_and_exit "\nCheck is valid network or not... ERROR - Invalid network - $NETWORK! Please choose of the following: ${VALID_NETWORK_LIST[*]}"
    fi

    if [ -z $NODE_KEY ]; then
        display_error_and_exit "\nCheck is valid node key or not... ERROR - Node key is empty. Please enter some string like 'fuse-[customer]-[role_name]'."
    elif [ ${#NODE_KEY} -lt 8 ]; then
        display_error_and_exit "\nCheck is valid node key or not... ERROR - Node key characters lower than 8 symbols. Please enter some string like 'fuse-[customer]-[role_name]'."
    else
        echo -e "\nCheck is valid node key or not... OK!"
    fi
}

# Sanity checks - call all `check_...` functions
function sanity_checks() {
    echo -e "\nSanity checks..."

    # Check OS
    check_os

    # Check is all needed tools are installed
    check_install_tools

    # Check Docker and Docker Compose install
    check_install_docker

    # Check disk space
    check_disk_space

    # Check RAM memory space
    check_ram_memory_space

    # Check node arguments
    check_node_arguments

    echo -e "\nSanity checks finished successfully!"
}

# Setup - prepare node to run Fuse client
function setup() {
    echo -e "\nSetup..."

    # Install and configure NTP
    install_ntp

    if [ "$OVERRIDE_VERSION_FILE" == false ] ; then
        echo -e "\nGrab docker Versions"
        if [[ $NETWORK == "spark" ]]; then
            VERSION_FILE="$SPARK_VERSION_FILE"
        fi
        wget -O versionFile $VERSION_FILE
        export $(grep -v '^#' versionFile | xargs)
    else
        echo -e "\n Using hardcoded version Info"
    fi

    # Specify image versions (generic)
    FUSE_CLIENT_DOCKER_REPOSITORY="fusenet/node"
    FUSE_CLIENT_DOCKER_IMAGE_VERSION="$DOCKER_IMAGE_NM_CLIENT"

    # Specify images / versions (Spark)
    SPARK_VALIDATOR_DOCKER_REPOSITORY="fusenet/spark-validator-app"
    SPARK_VALIDATOR_DOCKER_IMAGE_VERSION="$DOCKER_IMAGE_NM_CLIENT"

    SPARK_NETSTATS_CLIENT_DOCKER_REPOSITORY="fusenet/spark-netstat"
    SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION="$DOCKER_IMAGE_NET_STATS_VERSION"

    # Specify images / versions (Fuse)
    FUSE_VALIDATOR_DOCKER_REPOSITORY="fusenet/validator-app"
    FUSE_VALIDATOR_DOCKER_IMAGE_VERSION="$DOCKER_IMAGE_FUSE_APP_VERSION"

    NETSTATS_CLIENT_DOCKER_REPOSITORY="fusenet/netstat"
    NETSTATS_CLIENT_DOCKER_IMAGE_VERSION="$DOCKER_IMAGE_NET_STATS_VERSION"

    # Specify entire image (generic)
    FUSE_CLIENT_DOCKER_IMAGE=$FUSE_CLIENT_DOCKER_REPOSITORY:$FUSE_CLIENT_DOCKER_IMAGE_VERSION

    # Specify entire image (Spark)
    SPARK_VALIDATOR_DOCKER_IMAGE=$SPARK_VALIDATOR_DOCKER_REPOSITORY:$SPARK_VALIDATOR_DOCKER_IMAGE_VERSION
    SPARK_NETSTATS_CLIENT_DOCKER_IMAGE=$SPARK_NETSTATS_CLIENT_DOCKER_REPOSITORY:$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION

    # Specify entire image (Fuse)
    FUSE_VALIDATOR_DOCKER_IMAGE=$FUSE_VALIDATOR_DOCKER_REPOSITORY:$FUSE_VALIDATOR_DOCKER_IMAGE_VERSION
    NETSTATS_CLIENT_DOCKER_IMAGE=$NETSTATS_CLIENT_DOCKER_REPOSITORY:$NETSTATS_CLIENT_DOCKER_IMAGE_VERSION

    echo -e "\nFuse - Client: $FUSE_CLIENT_DOCKER_IMAGE_VERSION"

    if [[ $NETWORK == "spark" ]]; then
        # Print versions
        echo -e "Fuse - Netstat: $SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION"

        echo -e "\nPull Docker images...\n"

        if [[ $ROLE == "validator" ]]; then
            echo -e "Fuse - Validator: $SPARK_VALIDATOR_DOCKER_IMAGE_VERSION"
            $PERMISSION_PREFIX docker pull $SPARK_VALIDATOR_DOCKER_IMAGE
        fi

        # Pull needed Docker images
        $PERMISSION_PREFIX docker pull $FUSE_CLIENT_DOCKER_IMAGE
        $PERMISSION_PREFIX docker pull $SPARK_NETSTATS_CLIENT_DOCKER_IMAGE
    else
        # Print versions
        echo -e "\nFuse - Client: $FUSE_CLIENT_DOCKER_IMAGE_VERSION"
        echo -e "Fuse - Netstat: $NETSTATS_CLIENT_DOCKER_IMAGE_VERSION"

        echo -e "\nPull Docker images...\n"

        if [[ $ROLE == "validator" ]]; then
            echo -e "Fuse - Validator: $FUSE_VALIDATOR_DOCKER_IMAGE_VERSION"
            $PERMISSION_PREFIX docker pull $FUSE_VALIDATOR_DOCKER_IMAGE
        fi

        # Pull needed Docker images
        $PERMISSION_PREFIX docker pull $FUSE_CLIENT_DOCKER_IMAGE
        $PERMISSION_PREFIX docker pull $NETSTATS_CLIENT_DOCKER_IMAGE
    fi

    # Directories
    BASE_DIR="$(pwd)/fusenet"
    DATABASE_DIR=$BASE_DIR/database
    LOGS_DIR=$BASE_DIR/logs
    KEYSTORE_DIR=$BASE_DIR/keystore

    # Create needed directories
    mkdir -p $BASE_DIR
    mkdir -p $DATABASE_DIR
    mkdir -p $LOGS_DIR
    mkdir -p $KEYSTORE_DIR

    # Generate keystore file
    if [[ $ROLE == "validator" ]]; then
        if ls $KEYSTORE_DIR/UTC--**; then

            PUBLIC_ADDRESS=$($PERMISSION_PREFIX cat $KEYSTORE_DIR/UTC--* | jq -r '.address')

            echo -e "\nPrivate key is present in directory. You public address - 0x$PUBLIC_ADDRESS"

            echo -e "\nSkipping creating new private key..."
        else
            generate_eth_private_key
        fi
    fi
}

# Run - run needed Docker containers
function run() {
    echo -e "\nDelete old containers if it's exist..."

    # Delete old containers if they're exists
    $PERMISSION_PREFIX docker container rm -f fuse spark validator netstats >/dev/null 2>&1

    echo -e "\nDone!"

    echo -e "\nRun Docker container for ${NETWORK^} network. Role - ${ROLE^}"

    # Specify needed variables (Spark)

    # For node / bootnode
    if [[ $NETWORK == "spark" ]] && [[ $ROLE == "node" || $ROLE == "bootnode" ]]; then
        CONTAINER_NAME="spark"
        DB_PREFIX="spark"
        CONFIG="spark"

        NETSTATS_DOCKER_IMAGE=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    fi

    # For explorer (archive)
    if [[ $NETWORK == "spark" && $ROLE == "explorer" ]]; then
        CONTAINER_NAME="spark"
        DB_PREFIX="spark_archive"
        CONFIG="spark_archive"

        NETSTATS_DOCKER_IMAGE=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    fi

    # For validator
    if [[ $NETWORK == "spark" && $ROLE == "validator" ]]; then
        CONTAINER_NAME="spark"
        DB_PREFIX="spark"
        CONFIG="spark_validator"

        VALIDATOR_DOCKER_IMAGE=$SPARK_VALIDATOR_DOCKER_IMAGE
        NETSTATS_DOCKER_IMAGE=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    fi

    # Specify needed variables (Fuse)

    # For node / bootnode
    if [[ $NETWORK == "fuse" ]] && [[ $ROLE == "node" || $ROLE == "bootnode" ]]; then
        CONTAINER_NAME="fuse"
        DB_PREFIX="fuse"
        CONFIG="fuse"

        NETSTATS_DOCKER_IMAGE=$NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    fi

    # For explorer (archive)
    if [[ $NETWORK == "fuse" && $ROLE == "explorer" ]]; then
        CONTAINER_NAME="fuse"
        DB_PREFIX="fuse_archive"
        CONFIG="fuse_archive"

        NETSTATS_DOCKER_IMAGE=$NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    fi

    # For validator
    if [[ $NETWORK == "fuse" && $ROLE == "validator" ]]; then
        CONTAINER_NAME="fuse"
        DB_PREFIX="fuse_validator"
        CONFIG="fuse_validator"

        VALIDATOR_DOCKER_IMAGE=$FUSE_VALIDATOR_DOCKER_IMAGE
        NETSTATS_DOCKER_IMAGE=$NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    fi

    # Run Docker container
    if [[ $ROLE == "node" || $ROLE == "bootnode" || $ROLE == "explorer" ]]; then
        $PERMISSION_PREFIX docker run \
            --detach \
            --name $CONTAINER_NAME \
            --volume $DATABASE_DIR:/nethermind/nethermind_db/$DB_PREFIX \
            --volume $KEYSTORE_DIR:/nethermind/keystore \
            --volume $LOGS_DIR:/nethermind/logs \
            --log-opt max-size=10m \
            --log-opt max-file=25 \
            --log-opt compress=true \
            -p 30303:30300/tcp \
            -p 30303:30300/udp \
            -p 8545:8545 \
            -p 8546:8546 \
            --restart always \
            $FUSE_CLIENT_DOCKER_IMAGE \
            --config $CONFIG \
            --Init.WebSocketsEnabled true \
            --HealthChecks.Enabled true \
            --HealthChecks.Slug /api/health

        # Run Netstat
        $PERMISSION_PREFIX docker run \
            --detach \
            --name "netstats" \
            --net container:$CONTAINER_NAME \
            --log-opt max-size=10m \
            --log-opt max-file=25 \
            --log-opt compress=true \
            --restart always \
            --memory "250m" \
            $NETSTATS_DOCKER_IMAGE \
            --instance-name $NODE_KEY \
            --role ${ROLE^} \
            --netstats-version $NETSTATS_VERSION
    fi

    if [[ $ROLE == "validator" ]]; then
        $PERMISSION_PREFIX docker run \
            --detach \
            --name $CONTAINER_NAME \
            --volume $DATABASE_DIR:/nethermind/nethermind_db/$DB_PREFIX \
            --volume $KEYSTORE_DIR:/nethermind/keystore \
            --volume $LOGS_DIR:/nethermind/logs \
            --log-opt max-size=10m \
            --log-opt max-file=25 \
            --log-opt compress=true \
            -p 30303:30300/tcp \
            -p 30303:30300/udp \
            -p 8545:8545 \
            -p 8546:8546 \
            --restart always \
            $FUSE_CLIENT_DOCKER_IMAGE \
            --config $CONFIG \
            --KeyStore.PasswordFiles "keystore/pass.pwd" \
            --KeyStore.EnodeAccount "0x$PUBLIC_ADDRESS" \
            --KeyStore.UnlockAccounts "0x$PUBLIC_ADDRESS" \
            --KeyStore.BlockAuthorAccount "0x$PUBLIC_ADDRESS" \
            --HealthChecks.Enabled true \
            --HealthChecks.Slug /api/health

        # Run Validator app
        $PERMISSION_PREFIX docker run \
            --detach \
            --name "validator" \
            --volume $KEYSTORE_DIR:/config/keys/FuseNetwork \
            --volume $KEYSTORE_DIR/pass.pwd:/config/pass.pwd \
            --restart always \
            $VALIDATOR_DOCKER_IMAGE

        # Run Netstat
        $PERMISSION_PREFIX docker run \
            --detach \
            --name "netstats" \
            --net container:$CONTAINER_NAME \
            --log-opt max-size=10m \
            --log-opt max-file=25 \
            --log-opt compress=true \
            --restart always \
            --memory "250m" \
            $NETSTATS_DOCKER_IMAGE \
            --instance-name "${NODE_KEY}_0x${PUBLIC_ADDRESS}" \
            --role ${ROLE^} \
            --netstats-version $NETSTATS_VERSION \
            --fuseapp-version "1.0.0"
    fi

    # Get ENODE public address
    get_enode
}

# Get ENODE public address
function get_enode() {
    # Need to wait 30 seconds to fetch ENODE URL endpoint
    echo -e "\nYou must wait 15 seconds for the node to start and initialize..."

    sleep 15

    echo -e "\nRetriving enode public address...\n"

    # Identify ENODE address
    ENODE=$(curl --silent -X POST --data '{"jsonrpc":"2.0","method":"parity_enode","params":[],"id":67}' localhost:8545 | jq '.result')

    # Identify public IP address
    PERSONAL_PUBLIC_IP=$(curl ifconfig.me)

    # Print result
    ENODE_PUBLIC_ADDRESS=$(echo "${ENODE/"0.0.0.0"/$PERSONAL_PUBLIC_IP}")
    echo -e "\n${ENODE_PUBLIC_ADDRESS} - your public listen address."
}

# Function to create your private key
function generate_eth_private_key() {
    echo -e "\nGenerating your personal ETH priavate key...\n"

    while true; do
        read -s -r -p "Passphrase: " PASSPHRASE
        echo
        read -s -r -p "Passphrase (again): " PASSPHRASE_SECOND
        echo
        [ "$PASSPHRASE" = "$PASSPHRASE_SECOND" ] && break
        echo "Passphrases do not match, please try again"
    done

    echo "$PASSPHRASE" >$KEYSTORE_DIR/pass.pwd

    # Generate private key (Geth)
    $PERMISSION_PREFIX docker pull ethereum/client-go:stable
    $PERMISSION_PREFIX docker run --rm -v $KEYSTORE_DIR:/root/.ethereum/keystore ethereum/client-go:stable account new --password /root/.ethereum/keystore/pass.pwd >/dev/null 2>&1

    # Get full keystore file path
    KEYSTORE_FILE_PATH=$($PERMISSION_PREFIX find $KEYSTORE_DIR -type f -name "UTC--*")

    PUBLIC_ADDRESS=$($PERMISSION_PREFIX cat $KEYSTORE_DIR/UTC--* | jq -r '.address')

    echo -e "ETH public address: 0x$PUBLIC_ADDRESS." >$(pwd)/validator_info.txt

    echo -e "\nKeystore file: $KEYSTORE_FILE_PATH" >>$(pwd)/validator_info.txt

    echo -e "\nKeystore passphrase file: ${KEYSTORE_DIR}/pass.pwd\n\nNote: PLEASE DO NOT SHARE THIS FILE!" >>$(pwd)/validator_info.txt

    echo -e "\nAdd data stored in $(pwd)/validator_info.txt"
}

function unlock_account() {
    if [ ! "$(ls $KEYSTORE_DIR/UTC--**)" ]; then
        display_error_and_exit "No key store file found"
    fi

    pass=$(<"$KEYSTORE_DIR/pass.pwd")
    PUBLIC_ADDRESS=$($PERMISSION_PREFIX cat $KEYSTORE_DIR/UTC--* | jq -r '.address')
    
    RESULT=$(curl localhost:8545 -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept: application/json, text/plain, /' -H 'Cache-Control: no-cache' -X \
    POST --data '{"jsonrpc":"2.0","method":"personal_unlockAccount","params":["'"$PUBLIC_ADDRESS"'", "'"$pass"'"],"id":67}' | jq '.result')

    if [[ "$RESULT" != "true" ]]; then
        display_error_and_exit "Failed to unlock account"
    fi
}

function lock_account() {
    if [ ! "$(ls $KEYSTORE_DIR/UTC--**)" ]; then
        display_error_and_exit "No key store file found"
    fi

    PUBLIC_ADDRESS=$($PERMISSION_PREFIX cat $KEYSTORE_DIR/UTC--* | jq -r '.address')

    RESULT=$(curl localhost:8545 -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept: application/json, text/plain, /' -H 'Cache-Control: no-cache' -X \
    POST --data '{"jsonrpc":"2.0","method":"personal_lockAccount","params":["'"$PUBLIC_ADDRESS"'"],"id":67}' | jq '.result')

    if [[ "$RESULT" != "true" ]]; then
        display_error_and_exit "Failed to lock account"
    fi
}

function send_tx_to_consensus() {
    local DATA=$1
    if [[ $DATA == "" ]]; then
        display_error_and_exit "No data supplied cannot send message to consensus"
    fi

    if [ ! "$($PERMISSION_PREFIX docker ps -q -f name=fuse)" ]; then
        display_error_and_exit "Fuse container not running cannot send tx to consensus"
    fi

    unlock_account

    if [[ $NETWORK == "spark" ]]; then
        CONSENSUS_ADDR="0xC8c3a332f9e4CE6bfFFcf967026cB006Db2311c7"
    else
        CONSENSUS_ADDR="0x3014ca10b91cb3D0AD85fEf7A3Cb95BCAc9c0f79"
    fi

    PUBLIC_ADDRESS=$($PERMISSION_PREFIX cat $KEYSTORE_DIR/UTC--* | jq -r '.address')
    NONCE=$(curl localhost:8545 -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept: application/json, text/plain, /' -H 'Cache-Control: no-cache' -X POST --data \
    '{"jsonrpc":"2.0","method":"eth_getTransactionCount","params":["'"$PUBLIC_ADDRESS"'"],"id":67}' | jq '.result')


    TXHASH=$(curl --data '{"jsonrpc":"2.0","method":"eth_sendTransaction","params":[{"from":"'"$PUBLIC_ADDRESS"'","to":"'"$CONSENSUS_ADDR"'","value":0, \
    "Nonce":"'"$NONCE"'", "Gas":"1000000","GasPrice":"10000000000","ChainId":"122","Data":"'"$DATA"'"}],"id":67}' -H "Content-Type: application/json" -X POST localhost:8545 | jq '.result')

    echo -e "\nRequest sent TX_ID = ${TXHASH}"

    lock_account
}

# Function to create version.`date`.txt file
function generate_version_file() {
    date=$(date '+%Y-%m-%d')

    echo -e "\nCreate / override version.txt.${date} file..."

    echo -e "ROLE=${ROLE}" >version.txt.$date
    echo -e "\nENODE_PUBLIC_ADDRESS=${ENODE_PUBLIC_ADDRESS}" >>version.txt.$date
    echo -e "\nFUSE_CLIENT_VERSION=${FUSE_CLIENT_DOCKER_IMAGE_VERSION}" >>version.txt.$date
    echo -e "\nNETSTATS_CLIENT_VERSION=${NETSTATS_CLIENT_DOCKER_IMAGE_VERSION}" >>version.txt.$date
}

# Help

Help() {
    echo "The Fuse client - Bootstrap your own node."
    echo
    echo "Description:"
    echo "  Script allow to run locally your own Fuse node based on specific role."
    echo
    echo "Note:"
    echo "  quickstart.sh supports next Linux / Unix based distributions: Ubuntu, Debian, Fedora, CentOS, RHEL."
    echo
    echo "Usage:"
    echo "  ./quickstart.sh [-r|-n|-k||-v|-h]"
    echo
    echo "Options:"
    echo "  -r  Specify needed node role. Available next roles: 'node', 'bootnode', 'explorer', 'validator'"
    echo "  -n  Network (mainnet or testnet). Available next values: 'fuse' and 'spark'"
    echo "  -k  Node key name for https://health.fuse.io. Example: 'my-own-fuse-node'"
    echo "  -v  Script version"
    echo "  -u  Unjail a node"
    echo "  -m  Flag a node for maintenance"
    echo "  -h  Help page"
}

# Check if any options presents after script
if [ $# -lt 1 ]; then
    Help
    exit 1
fi

# Check is right argument specified
check_args() {
    if [[ $OPTARG =~ ^-[r/n/k/v/h/u/m]$ ]]; then
        display_error_and_exit "Unknow argument $OPTARG for option $opt!"
    fi
}

# Parse arguments
while getopts ":r:n:k:vhum" flag; do
    case "${flag}" in
    r)
        check_args
        ROLE=${OPTARG}
        ;;
    n)
        check_args
        NETWORK=${OPTARG}
        ;;
    k)
        check_args
        NODE_KEY=${OPTARG}
        ;;
    u)
        check_args
        send_tx_to_consensus "0x6eae5b11"
        exit 1
        ;;
    m)
        check_args
        send_tx_to_consensus "0x6c376cc5"
        exit 1
        ;;
    v)
        check_args
        echo $QUICKSTART_VERSION
        exit 1
        ;;
    h)
        check_args
        Help
        exit 1
        ;;
    *)
        echo "No reasonable options found!"
        exit 1
        ;;
    esac
done

# Go go go!
echo -e "Start / update your own Fuse (Spark) node!"

# Check all pre - requirements (needed env variables, installed tools, etc.)
sanity_checks

# Prepare node - pull latest Docker images create needed directories
setup

# Run
run

# Specify version file with client / netstat version, role, etc.
generate_version_file

echo -e "\nContainers started and running in background!"
