#!/usr/bin/env bash

BLACKBOX_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    unzip \
"

if [[ ${BLACKBOX_VERSION} != none ]]; then
    echo "Setup Blackbox v${BLACKBOX_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    BLACKBOX_URL=https://github.com/StackExchange/blackbox/archive/refs/tags/${BLACKBOX_VERSION}.zip
    if [[ ${BLACKBOX_VERSION} = latest ]]; then
        BLACKBOX_URL=https://github.com/StackExchange/blackbox/archive/refs/heads/master.zip
    fi

    curl -sSL -o /tmp/blackbox.zip ${BLACKBOX_URL}

    mkdir -p /tmp/blackbox
    unzip -o /tmp/blackbox.zip -d /tmp/blackbox

    cd /tmp/blackbox/blackbox-*
    make copy-install
    cd -

    rm -rf /tmp/blackbox /tmp/blackbox.zip

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
