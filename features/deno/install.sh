#!/usr/bin/env bash

DENO_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${DENO_VERSION} != none ]]; then
    echo "Setup Deno v${DENO_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64-unknown-linux-gnu;;
        arm64) ARCHITECTURE=aarch64-unknown-linux-gnu;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${DENO_VERSION} = latest ]]; then
        DENO_VERSION=$(curl -sSL https://api.github.com/repos/denoland/deno/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${DENO_VERSION} != v* ]]; then
        DENO_VERSION=v${DENO_VERSION}
    fi

    curl -sSL -o /tmp/deno.zip https://github.com/denoland/deno/releases/download/${DENO_VERSION}/deno-${ARCHITECTURE}.zip
    curl -sSL -o /tmp/SHASUMS256.txt https://github.com/denoland/deno/releases/download/${DENO_VERSION}/deno-${ARCHITECTURE}.zip.sha256sum

    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/deno.zip | cut -d ' ' -f 1)"

    unzip -o /tmp/deno.zip -d /usr/local/bin

    chmod +x /usr/local/bin/deno
    rm -rf /tmp/deno.zip /tmp/SHASUMS256.txt

    echo "Done!"
fi
