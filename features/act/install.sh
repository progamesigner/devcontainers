#!/usr/bin/env bash

ACT_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${ACT_VERSION} != none ]]; then
    echo "Setup act v${ACT_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=arm64;;
        armhf) ARCHITECTURE=armv7;;
        i386) ARCHITECTURE=x386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${ACT_VERSION} = latest ]]; then
        ACT_VERSION=$(curl -sSL https://api.github.com/repos/nektos/act/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${ACT_VERSION} != v* ]]; then
        ACT_VERSION=v${ACT_VERSION}
    fi

    curl -sSL -o /tmp/act.tar.gz https://github.com/nektos/act/releases/download/${ACT_VERSION}/act_Linux_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/act.tar.gz.asc https://github.com/nektos/act/releases/download/${ACT_VERSION}/checksums.txt

    cat /tmp/act.tar.gz.asc | grep "$(sha256sum /tmp/act.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/act
    tar -xz -f /tmp/act.tar.gz -C /tmp/act
    cp -v /tmp/act/act /usr/local/bin/act

    rm -rf /tmp/act /tmp/act.tar.gz.asc /tmp/act.tar.xz
fi
