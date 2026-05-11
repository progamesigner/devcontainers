#!/usr/bin/env bash

COPILOT_CLI_VERSION=${VERSION:-${1:-latest}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${COPILOT_CLI_VERSION} != none ]]; then
    echo "Setup GitHub Copilot CLI v${COPILOT_CLI_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x64;;
        arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${COPILOT_CLI_VERSION} = latest ]]; then
        COPILOT_CLI_VERSION=$(curl -sSL https://api.github.com/repos/github/copilot-cli/releases/latest | jq -r ".tag_name")
        COPILOT_CLI_VERSION=${COPILOT_CLI_VERSION#v}
    fi

    curl -sSL -o /tmp/copilot-cli.tar.gz https://github.com/github/copilot-cli/releases/download/v${COPILOT_CLI_VERSION}/copilot-linux-${ARCHITECTURE}.tar.gz

    mkdir -p /usr/local/share/copilot-cli/bin
    tar -xz -f /tmp/copilot-cli.tar.gz -C /usr/local/share/copilot-cli/bin
    chmod +x /usr/local/share/copilot-cli/bin/copilot

    rm -rf /tmp/copilot-cli.tar.gz

    echo "Done!"
fi
