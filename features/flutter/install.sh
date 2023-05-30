#!/usr/bin/env bash

FLUTTER_VERSION=${VERSION:-${1:-none}}
FLUTTER_CHANNEL=${CHANNEL:-${2:-stable}}
USERNAME=${USERNAME:-${1:-vscode}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    clang \
    cmake \
    libgtk-3-dev \
    liblzma-dev \
    ninja-build \
    pkg-config \
"

if [[ ${FLUTTER_VERSION} != none ]]; then
    curl -sSL -o /tmp/flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    mkdir -p /opt/flutter
    chown -v ${USERNAME}:${USERNAME} /opt/flutter

    tar -xJ -f /tmp/flutter.tar.xz -C /opt/flutter --strip-components=1

    rm -rf /tmp/flutter.tar.xz

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
