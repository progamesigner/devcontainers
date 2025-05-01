#!/usr/bin/env bash

WATCHMAN_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${WATCHMAN_VERSION} != none ]]; then
    echo "Setup watchman v${WATCHMAN_VERSION} ..."

    if [[ ${WATCHMAN_VERSION} = latest ]]; then
        WATCHMAN_VERSION=$(curl -sSL https://api.github.com/repos/facebook/watchman/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${WATCHMAN_VERSION} != v* ]]; then
        WATCHMAN_VERSION=v${WATCHMAN_VERSION}
    fi

    curl -sSL -o /tmp/watchman.deb https://github.com/facebook/watchman/releases/download/${WATCHMAN_VERSION}/watchman_ubuntu22.04_${WATCHMAN_VERSION}.deb

    apt-get install --fix-broken --yes /tmp/watchman.deb

    rm -rf /tmp/watchman.deb
fi
