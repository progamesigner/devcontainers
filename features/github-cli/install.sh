#!/usr/bin/env bash

GITHUB_CLI_VERSION=${VERSION:-${1:-latest}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${GITHUB_CLI_VERSION} != none ]]; then
    echo "Setup GitHub CLI v${GITHUB_CLI_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        i386) ARCHITECTURE=386;;
        amd64) ARCHITECTURE=amd64;;
        aarch64|armv8*|arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${GITHUB_CLI_VERSION} = latest ]]; then
        GITHUB_CLI_VERSION=$(curl -sSL https://api.github.com/repos/cli/cli/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${GITHUB_CLI_VERSION} != v* ]]; then
        GITHUB_CLI_VERSION=v${GITHUB_CLI_VERSION}
    fi

    curl -sSL -o /tmp/github-cli.tar.gz https://github.com/cli/cli/releases/download/${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION#v}_linux_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/github-cli.tar.gz.asc https://github.com/cli/cli/releases/download/${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION#v}_checksums.txt

    cat /tmp/github-cli.tar.gz.asc | grep "$(sha256sum /tmp/github-cli.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/github-cli
    tar -xz -f /tmp/github-cli.tar.gz -C /tmp/github-cli --strip-components=1
    cp -v /tmp/github-cli/bin/gh /usr/local/bin/gh

    rm -rf /tmp/github-cli /tmp/github-cli.tar.gz.asc /tmp/github-cli.tar.gz

    echo "Done!"
fi
