#!/usr/bin/env bash

BUN_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${BUN_VERSION} != none ]]; then
    echo "Setup Bun v${BUN_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x64;;
        arm64) ARCHITECTURE=aarch64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [ -f /etc/alpine-release ]; then
        ARCHITECTURE=${ARCHITECTURE}-musl
    fi

    if [[ ${ARCHITECTURE} = x64* ]] && [[ $(cat /proc/cpuinfo | grep avx2) = "" ]]; then
        ARCHITECTURE=${ARCHITECTURE}-baseline
    fi

    if [[ ${BUN_VERSION} = latest ]]; then
        BUN_VERSION=$(curl -sSL https://api.github.com/repos/oven-sh/bun/releases/latest | jq -r ".tag_name")
        BUN_VERSION=${BUN_VERSION#bun-}
    fi

    if [[ ${BUN_VERSION} != v* ]]; then
        BUN_VERSION=v${BUN_VERSION}
    fi

    curl -sSL -o /tmp/bun.zip https://github.com/oven-sh/bun/releases/download/bun-${BUN_VERSION}/bun-linux-${ARCHITECTURE}.zip
    curl -sSL -o /tmp/SHASUMS256.txt https://github.com/oven-sh/bun/releases/download/bun-${BUN_VERSION}/SHASUMS256.txt

    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/bun.zip | cut -d ' ' -f 1)"

    mkdir -p /tmp/bun
    unzip -o /tmp/bun.zip -d /tmp/bun

    mv /tmp/bun/bun-linux-${ARCHITECTURE}/bun /usr/local/bin/bun
    chmod +x /usr/local/bin/bun

    rm -rf /tmp/bun /tmp/bun.zip /tmp/SHASUMS256.txt

    echo "Done!"
fi
