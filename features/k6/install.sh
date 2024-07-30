#!/usr/bin/env bash

K6_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${K6_VERSION} != none ]]; then
    echo "Setup k6 v${K6_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${K6_VERSION} = latest ]]; then
        K6_VERSION=$(curl -sSL https://api.github.com/repos/grafana/k6/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${K6_VERSION} != v* ]]; then
        K6_VERSION=v${K6_VERSION}
    fi

    curl -sSL -o /tmp/k6.tar.gz https://github.com/grafana/k6/releases/download/${K6_VERSION}/k6-${K6_VERSION}-linux-${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/k6.tar.gz.asc https://github.com/grafana/k6/releases/download/${K6_VERSION}/k6-${K6_VERSION}-checksums.txt

    cat /tmp/k6.tar.gz.asc | grep "$(sha256sum /tmp/k6.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/k6
    tar -xz -f /tmp/k6.tar.gz -C /tmp/k6 --strip-components=1
    cp -v /tmp/k6/k6 /usr/local/bin/k6

    rm -rf /tmp/k6 /tmp/k6.tar.gz.asc /tmp/k6.tar.gz

    echo "Done!"
fi
