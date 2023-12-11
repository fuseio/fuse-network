#!/bin/bash

set -e

function update-quickstart {
  echo -e "\nDowloading latest quickstart from GitHub"
  wget -O quickstart.sh "https://raw.githubusercontent.com/fuseio/fuse-network/master/scripts/quickstart.sh"
  chmod 777 quickstart.sh
}

function run-quickstart {
  ./quickstart.sh
}

update-quickstart
run-quickstart