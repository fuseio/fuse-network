#!/bin/bash

set -e

# in case "sudo" is needed
PERMISSION_PREFIX=""

function docker {
  echo -e "\nInstalling docker..."

  $PERMISSION_PREFIX apt-get update

  $PERMISSION_PREFIX apt-get install \
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

  $PERMISSION_PREFIX apt-get install docker-ce docker-ce-cli containerd.io
}

function docker-compose {
  echo -e "\nInstalling docker-compose..."

  $PERMISSION_PREFIX curl -L "https://github.com/docker/compose/releases/download/1.23.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

  $PERMISSION_PREFIX chmod +x /usr/local/bin/docker-compose

  $PERMISSION_PREFIX ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
}

function config {
  echo -e "\nDowloading config files and scripts..."

  wget -O quickstart.sh "https://raw.githubusercontent.com/fuseio/fuse-network/master/scripts/quickstart.sh"

  chmod +x quickstart.sh

  wget -O .env "https://raw.githubusercontent.com/fuseio/fuse-network/master/scripts/examples/.env.validator.example"

  wget -O clean-docker.sh "https://raw.githubusercontent.com/fuseio/fuse-network/master/scripts/clean-docker.sh"

  chmod +x clean-docker.sh
}

# Go :)
docker
docker-compose
config