#!/bin/bash

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

function is_root() {
    uid=$(id | sed -En 's/.*uid=([0-9]*).*/\1/p')
    if [ "${uid}" -ne 0 ]; then
        echo "${RED}You need to run this script as root${NC}"
        exit 1
    fi
}


function isRoot() {
  if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
  fi
}



function installPackages() {
  if ! "$@"; then
    echo -e "${RED}Failed to install packages.${NC}"
    echo "Please check your internet connection and package sources."
    exit 1
  fi
}

