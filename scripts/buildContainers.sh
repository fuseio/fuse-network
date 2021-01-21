#!/bin/bash

set -e
DOCKER_IMAGE_APP="fusenet/validator-app"
DOCKER_IMAGE_PARITY="fusenet/node"

PLATFORM=""
PLATFORM_VARIENT=""

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

function install_docker {
  echo -e "\nInstalling docker..."
  if [ $PLATFORM_VARIENT == "Ubuntu" ]; then
    apt-get update

    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg-agent \
        software-properties-common

    curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | apt-key add -

    add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) \
       stable"

    apt-get update

    apt-get install -y docker-ce docker-ce-cli containerd.io
  elif [ $PLATFORM_VARIENT == "Debian" ]; then
    apt update
    
    apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common
    
    curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
    
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

    apt update
    apt-cache policy docker-ce
    apt install docker-ce docker-ce-cli containerd.io
  else
    displayErrorAndExit "UNKNOWN OS please install docker"
  fi
}

function install_hub {
  if [ $PLATFORM == "LINUX" ]; then
    if [ $PLATFORM_VARIENT == "Ubuntu" ]; then
      apt update
      apt install snapd
      snap install hub --classic
    elif [ $PLATFORM_VARIENT == "Debian" ]; then
      apt install hub
    else
      displayErrorAndExit "UNKNOWN OS please install hub manually"
    fi
  elif [ $PLATFORM == "MAC" ]; then
    brew install hub
  else
    displayErrorAndExit "UNKNOWN OS please install hub manually"
  fi
}

function installDeps {
  #assume git already installed....
  install_docker
  install_hub
  
  $PLATFORM_VARIENT docker login
}

setPlatform
readVersion
PS3='Please enter your choice: '
options=("Build Fuse APP container" "Build Fuse Parity container" "Build both" "First time configure" "Exit")
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
      #Configure
      echo "Configure env"
      installDeps
      break
    ;;
    "${options[4]}")
      #Exit
      exit 0
    ;;
    *) echo "invalid option $REPLY";;
  esac
done