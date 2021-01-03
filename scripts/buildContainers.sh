#!/bin/bash

set -e
DOCKER_IMAGE_APP="fusenet/validator-app"
DOCKER_IMAGE_PARITY="fusenet/node"


function readVersion {
  export $(grep -v '^#' "../Version" | xargs)
}

function buildFuseApp {
  read -p "Please input your new Version number for FuseApp (currentVersion=$DOCKER_IMAGE_FUSE_APP_VERSION): " newVersion
  
  docker build -t "$DOCKER_IMAGE_APP" ../app
  docker tag "$DOCKER_IMAGE_APP" "$DOCKER_IMAGE_APP:$newVersion"
  docker push "$DOCKER_IMAGE_APP:$newVersion"
  
  sed -i "s/^DOCKER_IMAGE_FUSE_APP_VERSION.*/DOCKER_IMAGE_FUSE_APP_VERSION=${newVersion}/" "../Version"
}

function buildFuseParity {
  read -p "Please input your new Version number for FuseParity (currentVersion=$DOCKER_IMAGE_FUSE_PARITY_VERSION): " newVersion
  
  docker build -t "$DOCKER_IMAGE_PARITY" ../
  docker tag "$DOCKER_IMAGE_PARITY" "$DOCKER_IMAGE_PARITY:$newVersion"
  docker push "$DOCKER_IMAGE_PARITY:$newVersion"
  
  sed -i "s/^DOCKER_IMAGE_FUSE_PARITY_VERSION.*/DOCKER_IMAGE_FUSE_PARITY_VERSION=${newVersion}/" "../Version"
}

function pushChanges {
  local appsChanged=$1
  branchName="update_$appsChanged"
  
  git branch -m "$branchName"
  git commit -m "$branchName" ../Version
  git push -u origin "$branchName"
  hub pull-request -m "$branchName"
}

readVersion
PS3='Please enter your choice: '
options=("Build Fuse APP container" "Build Fuse Parity container" "Build both" "Exit")
select opt in "${options[@]}";
do
  case $opt in
    "${options[0]}")
      #Build Fuse APP container
      echo "building fuse APP"
      buildFuseApp
      read -p "Do you want to push the new version file[Y/N]: " yn
      case $yn in
        [Y/y]* ) 
        pushChanges "FuseApp"; break;;
      esac
      break
    ;;
    "${options[1]}")
      #Build Fuse Parity container
      echo "building Fuse Parity"
      buildFuseParity
      read -p "Do you want to push the new version file[Y/N]: " yn
      case $yn in
        [Y/y]* ) 
        pushChanges "FuseParity"; break;;
      esac
      break
    ;;
    "${options[2]}")
      #Build both
      echo "building fuse APP"
      buildFuseApp
      echo "building Fuse Parity"
      buildFuseParity
      read -p "Do you want to push the new version file[Y/N]: " yn
      case $yn in
        [Y/y]* ) 
        pushChanges "FuseAPP_And_FuseParity"; break;;
      esac
      break
    ;;
    "${options[3]}")
      #Exit
      exit 0
    ;;
    *) echo "invalid option $REPLY";;
  esac
done