#!/usr/bin/env bash

NODE_VERSION=${1:-"none"}
NPM_HOME=${2:-"/usr/local/npm"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES="\
    dpkg-dev \
    xz-utils \
"

GPG_KEYS="\
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
"

if [ "${NODE_VERSION}" != "none" ]; then
    echo "Setup Node v${NODE_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x64;;
        arm64) ARCHITECTURE=arm64;;
        armhf) ARCHITECTURE=armv7l;;
        i386) ARCHITECTURE=x86;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/node.tar.xz https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCHITECTURE}.tar.xz
    curl -sSL -o /tmp/SHASUMS256.txt.asc https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt.asc

    export GNUPGHOME=$(mktemp -d)
    for GPG_KEY in ${GPG_KEYS}; do
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEY} || \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys ${GPG_KEY}
    done
    gpg --batch -d -o /tmp/SHASUMS256.txt /tmp/SHASUMS256.txt.asc
    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/node.tar.xz | cut -d ' ' -f 1)"
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    tar -xJ -f /tmp/node.tar.xz -C /usr/local --strip-components=1

    rm -rf /tmp/SHASUMS256.txt /tmp/SHASUMS256.txt.asc /tmp/node.tar.xz

    mkdir -p ${NPM_HOME}
    chmod a+rwx ${NPM_HOME}

    echo "prefix=${NPM_HOME}" >> /usr/local/etc/npmrc
    echo "if [[ "\${PATH}" != *"\${NPM_HOME}/bin"* ]]; then export PATH="\${NPM_HOME}/bin:\${PATH}"; fi" >> /etc/bash.bashrc
fi

echo "Done!"
