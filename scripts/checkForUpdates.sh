#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VERSION_FILE="https://raw.githubusercontent.com/fuseio/fuse-network/master/Version"

function updateContainers {
  "$DIR/quickstart.sh"
}

function getContainerImageNames {
  docker ps -a | awk '{ print $2 }'
}

function grabAndParseVersionFile {
  wget -O "$DIR/versionFile" $VERSION_FILE
  export $(grep -v '^#' versionFile | xargs)
  
  # Print versions
  echo "Oracle version = $DOCKER_IMAGE_ORACLE_VERSION"
  echo "Parity version = $DOCKER_IMAGE_FUSE_PARITY_VERSION"
  echo "Fuse app version = $DOCKER_IMAGE_FUSE_APP_VERSION"
  echo "Netstats version = $DOCKER_IMAGE_NET_STATS_VERSION"
}

function versionComp {
  local nodeName=$1
  local expectedVersion=$2
  if[[ $nodeName != "" ]] $$ [[ $expectedVersion != "" ]]; then
    if [[ $nodeName == *"$expectedVersion"* ]]; then
      return 0
    else
      return 1
    fi
  else
    echo "versionComp() needs 2 arguments"
  fi
  
  return 0
}

function checkContainers {
  grabAndParseVersionFile
  conatiners=$(getContainerImageNames)
  update=0
  
  for IMAGE_NAME_WITH_TAG in ${conatiners[@]}; do
    if [[ $IMAGE_NAME_WITH_TAG == *"netstat"* ]]; then
      #netstats container
      update=$(versionComp $IMAGE_NAME_WITH_TAG $DOCKER_IMAGE_NET_STATS_VERSION)
    elif [[ $IMAGE_NAME_WITH_TAG == *"validator-app"* ]]; then
      #fuseapp container
      update=$(versionComp $IMAGE_NAME_WITH_TAG $DOCKER_IMAGE_FUSE_APP_VERSION)
    elif [[ $IMAGE_NAME_WITH_TAG == *"node"* ]]; then
      #parity container
      update=$(versionComp $IMAGE_NAME_WITH_TAG $DOCKER_IMAGE_FUSE_PARITY_VERSION)
    elif [[ $IMAGE_NAME_WITH_TAG == *"native-to-erc20-oracle"* ]]; then
      #bridge container
      update=$(versionComp $IMAGE_NAME_WITH_TAG $DOCKER_IMAGE_ORACLE_VERSION)
    fi
    
    if [[ $update == 1 ]]; then
      break
    fi
  done
  
  if [[ $update == 1 ]]; then
    updateContainers
  fi
}

checkContainers