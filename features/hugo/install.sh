#!/usr/bin/env bash

HUGO_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    dpkg-dev \
    gzip \
"

if [[ ${HUGO_VERSION} != none ]]; then
    echo "Setup Hugo v${HUGO_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=64bit;;
        arm64) ARCHITECTURE=ARM64;;
        armhf) ARCHITECTURE=ARM;;
        i386) ARCHITECTURE=32bit;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${HUGO_VERSION} = latest ]]; then
        HUGO_VERSION=$(curl -sSL https://api.github.com/repos/gohugoio/hugo/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${HUGO_VERSION} != v* ]]; then
        HUGO_VERSION=v${HUGO_VERSION}
    fi

    curl -sSL -o /tmp/hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/${HUGO_VERSION}/hugo_${HUGO_VERSION#v}_Linux-${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/SHASUMS256.txt https://github.com/gohugoio/hugo/releases/download/${HUGO_VERSION}/hugo_${HUGO_VERSION#v}_checksums.txt

    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/hugo.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/hugo
    tar -xz -f /tmp/hugo.tar.gz -C /tmp/hugo
    cp -v /tmp/hugo/hugo /usr/local/bin/hugo

    rm -rf /tmp/hugo /tmp/SHASUMS256.txt /tmp/hugo.tar.xz

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
