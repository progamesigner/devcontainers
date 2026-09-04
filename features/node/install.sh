#!/usr/bin/env bash

NODE_VERSION=${VERSION:-${1:-none}}

NPM_CONFIG_PREFIX=${NPM_CONFIG_PREFIX:-/usr/local/npm}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    dpkg-dev \
    g++ \
    gcc \
    gnupg \
    libc-dev \
    make \
    python3 \
    xz-utils \
"

if [[ ${NODE_VERSION} != none ]]; then
    echo "Setup NodeJS v${NODE_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x64;;
        arm64) ARCHITECTURE=arm64;;
        armhf) ARCHITECTURE=armv7l;;
        i386) ARCHITECTURE=x86;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/node.tar.xz https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCHITECTURE}.tar.xz
    curl -sSL -o /tmp/node.tar.xz.asc https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt.asc

    export GNUPGHOME=$(mktemp -d)
    curl -sSL -o ${GNUPGHOME}/pubring.kbx https://raw.githubusercontent.com/nodejs/release-keys/main/gpg/pubring.kbx
    gpg --batch -d -o /tmp/SHASUMS256.txt /tmp/node.tar.xz.asc
    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/node.tar.xz | cut -d ' ' -f 1)"
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    tar -xJ -f /tmp/node.tar.xz -C /usr/local --strip-components=1

    rm -rf /tmp/SHASUMS256.txt /tmp/node.tar.xz.asc /tmp/node.tar.xz

    mkdir -p ${NPM_CONFIG_PREFIX}
    chmod a+rwx ${NPM_CONFIG_PREFIX}

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
