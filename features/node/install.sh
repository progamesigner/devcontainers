#!/usr/bin/env bash

NODE_VERSION=${VERSION:-${1:-none}}

NPM_HOME=${NPM_HOME:-/usr/local/npm}

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
    libc-dev \
    make \
    python3 \
    xz-utils \
"

GPG_KEYS=" \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    141F07595B7B3FFE74309A937405533BE57C7D57 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
    CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    A363A499291CBBC940DD62E41F10027AF002F8B0 \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    1C050899334244A8AF75E53792EF661D867B9DFA \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    93C7E9E91B49E432C2F75674B0A78B0A6C481CF6 \
    56730D5401028683275BD23C23EFEFE93C4CFFFE \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    61FC681DFB92A079F1685E77973F295594EC4689 \
    114F43EE0176B71C7BC219DD50A3051F888C628D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
    7937DFD2AB06298B2293C3187D33FF9D0246406D \
    C0D6248439F1D5604AAFFB4021D900FFDB233756 \
    5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 \
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
    gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys ${GPG_KEYS} || gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEYS} || true
    gpg --batch -d -o /tmp/SHASUMS256.txt /tmp/node.tar.xz.asc
    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/node.tar.xz | cut -d ' ' -f 1)"
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    tar -xJ -f /tmp/node.tar.xz -C /usr/local --strip-components=1

    rm -rf /tmp/SHASUMS256.txt /tmp/node.tar.xz.asc /tmp/node.tar.xz

    mkdir -p ${NPM_HOME}
    chmod a+rwx ${NPM_HOME}

    echo "if [[ "\${PATH}" != *"\${NPM_HOME}/bin"* ]]; then export PATH="\${NPM_HOME}/bin:\${PATH}"; fi" >> /etc/bash.bashrc

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
