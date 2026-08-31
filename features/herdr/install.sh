#!/usr/bin/env bash

HERDR_VERSION=${VERSION:-${1:-latest}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${HERDR_VERSION} != none ]]; then
    echo "Setup Herdr v${HERDR_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=aarch64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${HERDR_VERSION} = latest ]]; then
        HERDR_VERSION=$(curl -sSL https://api.github.com/repos/herdrdev/herdr/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${HERDR_VERSION} != v* ]]; then
        HERDR_VERSION=v${HERDR_VERSION}
    fi

    curl -sSL -o /tmp/herdr https://github.com/herdrdev/herdr/releases/download/${HERDR_VERSION}/herdr-linux-${ARCHITECTURE}

    SHA256=$(jq -er --arg name herdr-linux-${ARCHITECTURE} '.assets[] | select(.name == $name) | .digest | select(startswith("sha256:")) | sub("^sha256:"; "")' <<< $(curl -sSL https://api.github.com/repos/herdrdev/herdr/releases/tags/${HERDR_VERSION}))
    echo "${SHA256}  /tmp/herdr" | sha256sum --check --status

    mv /tmp/herdr /usr/local/bin/herdr
    chmod +x /usr/local/bin/herdr

    rm -rf /tmp/herdr

    echo "Done!"
fi
