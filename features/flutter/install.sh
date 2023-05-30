#!/usr/bin/env bash

FLUTTER_VERSION=${VERSION:-${1:-none}}
FLUTTER_CHANNEL=${CHANNEL:-${2:-stable}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${FLUTTER_VERSION} != none ]]; then
    curl -sSL -o /tmp/flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_CHANNEL}/linux/flutter_linux_${FLUTTER_VERSION}-${FLUTTER_CHANNEL}.tar.xz

    mkdir -p /opt/flutter
    tar -xJ -f /tmp/flutter.tar.xz -C /opt/flutter --strip-components=1

    rm -rf /tmp/flutter.tar.xz

    echo "Done!"
fi
