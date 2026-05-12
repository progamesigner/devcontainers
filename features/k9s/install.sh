#!/usr/bin/env bash

K9S_VERSION=${VERSION:-${1:-latest}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${K9S_VERSION} != none ]]; then
    echo "Setup k9s v${K9S_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        aarch64|armv8*|arm64) ARCHITECTURE=arm64;;
        armhf) ARCHITECTURE=armv7;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${K9S_VERSION} = latest ]]; then
        K9S_VERSION=$(curl -sSL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${K9S_VERSION} != v* ]]; then
        K9S_VERSION=v${K9S_VERSION}
    fi

    curl -sSL -o /tmp/k9s.tar.gz https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/k9s.tar.gz.asc https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/checksums.sha256

    cat /tmp/k9s.tar.gz.asc | grep "$(sha256sum /tmp/k9s.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/k9s
    tar -xz -f /tmp/k9s.tar.gz -C /tmp/k9s
    cp -v /tmp/k9s/k9s /usr/local/bin/k9s

    rm -rf /tmp/k9s /tmp/k9s.tar.gz.asc /tmp/k9s.tar.gz

    echo "Done!"
fi
