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

# Function to check OS
function check_os() {
    if [[ "$(uname)" == "Linux" ]]; then
        echo -e "\nYou're running script on Linux OS."
    else
        echo -e "\nYou're running script on non - Linux OS. Exit."
        exit 1
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
        echo -e "\nWe'd support next distributions: Ubuntu, Debian, CentOS, RHEL, Fedora. Please check out your distribution and install jq, curl tools."
        exit 1
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
        echo -e "\nWe'd support next distributions: Ubuntu, Debian, CentOS, Red Hat Enterprise Linux, Fedora. Please check out your distribution and install Docker."
        exit -1
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
        echo -e "\nWe'd support next distributions: Ubuntu, Debian, Red Hat Enterprise Linux, CentOS, Fedora. Please check out your distribution and install / configure NTP."
        exit 1
    fi

    $PERMISSION_PREFIX systemctl stop chronyd
    $PERMISSION_PREFIX chronyd -q 'server 0.europe.pool.ntp.org iburst'
    $PERMISSION_PREFIX systemctl start chronyd
    $PERMISSION_PREFIX systemctl enable chronyd
}

# Function to check disk space
function check_disk_space() {

    # Specify disk space treshold
    REQUIRED_DISK_SPACE_GB=50

    # We're using mount volume where is quickstart.sh file
    mounted_volume=$(df --output=target quickstart.sh | tail -n1)
    total_volume_size_mb=$(df -k --output=size "$mounted_volume" | tail -n1)
    total_volume_size_gb=$((total_volume_size_mb / 1024 / 1024))

    # Check with specified treshold
    if [ $total_volume_size_gb -lt $REQUIRED_DISK_SPACE_GB ]; then
        echo -e "\nCheck disk space.... ERROR - Not enoguh total drive space! you have $total_volume_size_gb GB you require at least $REQUIRED_DISK_SPACE_GB GB!"
        exit 1
    else
        echo -e "\nCheck disk space.... OK!"
    fi
}

# Function to check RAM memory space
function check_ram_memory_space() {

    # Specify RAM memory treshold
    REQUIRED_RAM_GB=2

    # Identify RAM memory amount
    total_ram_memory_size_mb=$(free -m | grep Mem: | awk '{print $2}')
    total_ram_memory_size_gb=$((total_ram_memory_size_mb / 1024))

    # Check with specified treshold
    if [ $total_ram_memory_size_gb -lt $REQUIRED_RAM_GB ]; then
        echo -e "\nCheck RAM memory space... ERROR - Not enoguh total RAM memory space! you have $total_volume_size_gb GB you require at least $REQUIRED_RAM_GB GB!"
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
        echo -e "\nCheck is valid role or not... ERROR - Invalid role - $ROLE! Please choose of the following: ${VALID_ROLE_LIST[*]}"
        exit 1
    fi

    if [[ ${VALID_NETWORK_LIST[*]} =~ "$NETWORK" ]]; then
        echo -e "\nCheck is valid network or not... OK!"
    else
        echo -e "\nCheck is valid network or not... ERROR - Invalid network - $NETWORK! Please choose of the following: ${VALID_NETWORK_LIST[*]}"
        exit 1
    fi

    if [ -z $NODE_KEY ]; then
        echo -e "\nCheck is valid node key or not... ERROR - Node key is empty. Please enter some string like 'fuse-[customer]-[role_name]'."
        exit 1
    elif [ ${#NODE_KEY} -lt 8 ]; then
        echo -e "\nCheck is valid node key or not... ERROR - Node key characters lower than 8 symbols. Please enter some string like 'fuse-[customer]-[role_name]'."
        exit 1
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

    # Specify image versions
    FUSE_CLIENT_DOCKER_REPOSITORY="fusenet/nethermind-node"

    NETSTATS_CLIENT_DOCKER_REPOSITORY="fusenet/netstat"
    SPARK_NETSTATS_CLIENT_DOCKER_REPOSITORY="fusenet/spark-netstat"

    FUSE_CLIENT_DOCKER_IMAGE_VERSION="1.13.3"

    NETSTATS_CLIENT_DOCKER_IMAGE_VERSION="1.0.0"
    SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION="1.0.0"

    FUSE_CLIENT_DOCKER_IMAGE=$FUSE_CLIENT_DOCKER_REPOSITORY:$FUSE_CLIENT_DOCKER_IMAGE_VERSION
    NETSTATS_CLIENT_DOCKER_IMAGE=$NETSTATS_CLIENT_DOCKER_REPOSITORY:$NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    SPARK_NETSTATS_CLIENT_DOCKER_IMAGE=$SPARK_NETSTATS_CLIENT_DOCKER_REPOSITORY:$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION

    echo -e "\nFuse - Client: $FUSE_CLIENT_DOCKER_IMAGE_VERSION"

    if [[ $NETWORK == "spark" ]]; then
        # Print versions
        echo -e "Fuse - Netstat: $SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION"

        echo -e "\nPull Docker images...\n"

        # Pull needed Docker images
        $PERMISSION_PREFIX docker pull $FUSE_CLIENT_DOCKER_IMAGE
        $PERMISSION_PREFIX docker pull $SPARK_NETSTATS_CLIENT_DOCKER_IMAGE
    else
        # Print versions
        echo -e "\nFuse - Client: $FUSE_CLIENT_DOCKER_IMAGE_VERSION"
        echo -e "Fuse - Netstat: $NETSTATS_CLIENT_DOCKER_IMAGE_VERSION"

        echo -e "\nPull Docker images...\n"

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
}

# Run - run needed Docker containers
function run() {
    echo -e "\nDelete old containers if it's exist..."

    # Delete old containers if they're exists
    $PERMISSION_PREFIX docker container rm -f fuse spark netstats >/dev/null 2>&1

    echo -e "\nDone!"

    echo -e "\nRun Docker container for ${NETWORK^} network. Role - ${ROLE^}"

    # Generate keystore file
    if [[ $ROLE == "validator" ]]; then
        generate_eth_private_key
    fi

    # Specify needed variables for Spark (if you're running node on Spark)

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
        DB_PREFIX="spark_validator"
        CONFIG="spark_validator"

        NETSTATS_DOCKER_IMAGE=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
    fi

    # Specify needed variables for Fuse (if you're running node on Fuse)

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

        NETSTATS_DOCKER_IMAGE=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE
        NETSTATS_VERSION=$SPARK_NETSTATS_CLIENT_DOCKER_IMAGE_VERSION
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
            --KeyStore.PasswordFiles "pass.pwd" \
            --KeyStore.EnodeAccount "key-$PUBLIC_ADDRESS" \
            --KeyStore.UnlockAccounts "0x$PUBLIC_ADDRESS" \
            --KeyStore.BlockAuthorAccount "0x$PUBLIC_ADDRESS" \
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
    $PERMISSION_PREFIX docker run --rm -v $KEYSTORE_DIR:/root/.ethereum/keystore ethereum/client-go:stable account new --password /root/.ethereum/keystore/pass.pwd

    # Get full keystore file path
    KEYSTORE_FILE_PATH=$($PERMISSION_PREFIX find $KEYSTORE_DIR -type f -name "UTC--*")

    PUBLIC_ADDRESS=$($PERMISSION_PREFIX cat $KEYSTORE_DIR/UTC--* | jq -r '.address')

    $PERMISSION_PREFIX mv $KEYSTORE_FILE_PATH $KEYSTORE_DIR/key-$PUBLIC_ADDRESS

    echo -e "\nETH public address: 0x$PUBLIC_ADDRESS."

    echo -e "\nKeystore file: $KEYSTORE_DIR/key-$PUBLIC_ADDRESS"

    echo -e "\nKeystore passphrase file: ${KEYSTORE_DIR}/pass.pwd\n\nNote: PLEASE DO NOT SHARE THIS FILE!\n"
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
    echo "  -r  Specify needed node role. Available next roles: 'node', 'bootnode', 'explorer'"
    echo "  -n  Network (mainnet or testnet). Available next values: 'fuse' and 'spark'"
    echo "  -k  Node key name for https://health.fuse.io. Example: 'my-own-fuse-node'"
    echo "  -v  Script version"
    echo "  -h  Help page"
}

# Check if any options presents after script
if [ $# -lt 1 ]; then
    Help
    exit 1
fi

# Check is right argument specified
check_args() {
    if [[ $OPTARG =~ ^-[r/n/k/v/h]$ ]]; then
        echo "Unknow argument $OPTARG for option $opt!"
        exit 1
    fi
}

# Parse arguments
while getopts ":r:n:k:vh" flag; do
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
