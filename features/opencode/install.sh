#!/usr/bin/env bash

OPENCODE_VERSION=${VERSION:-${1:-latest}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${OPENCODE_VERSION} != none ]]; then
    echo "Setup OpenCode v${OPENCODE_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x64;;
        arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ "$ARCHITECTURE" == "x64" ]] && ! grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
        ARCHITECTURE=${ARCHITECTURE}-baseline
    fi

    if [[ ${OPENCODE_VERSION} = latest ]]; then
        OPENCODE_VERSION=$(curl -sSL https://api.github.com/repos/anomalyco/opencode/releases/latest | jq -r ".tag_name")
        OPENCODE_VERSION=${OPENCODE_VERSION#v}
    fi

    curl -sSL -o /tmp/opencode.tar.gz https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${ARCHITECTURE}.tar.gz

    mkdir -p /usr/local/share/opencode/bin
    tar -xz -f /tmp/opencode.tar.gz -C /usr/local/share/opencode/bin
    chmod +x /usr/local/share/opencode/bin/opencode

    rm -rf /tmp/opencode.tar.gz

    echo "Done!"
fi
