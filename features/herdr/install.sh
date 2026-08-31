#!/usr/bin/env bash

HERDR_VERSION=${VERSION:-${1:-latest}}
HERDR_BRIDGE=${BRIDGE:-${2:-true}}
HERDR_BRIDGE_PORT=${BRIDGEPORT:-${3:-47990}}

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

# Bridge the host's HERDR_SOCKET_PATH Unix socket into the container.
#
# On Docker Desktop/OrbStack-style setups the container runs in a separate
# VM/kernel from the host, so a bind-mounted copy of the host's herdr.sock
# is just a stale file — connecting to it returns ECONNREFUSED, since a Unix
# domain socket is a live kernel object, not just file bytes. Bridging it
# over TCP via host.docker.internal, with a matching socat listener on the
# host side, is the only reliable way to reach it. See
# https://gist.github.com/progamesigner/0f90551cabaaf54ccc8407fe9944c9c9
# for the paired host-side LaunchAgent that this expects to be listening on
# HERDR_BRIDGE_PORT.
if [[ ${HERDR_BRIDGE} = true ]]; then
    echo "Setup Herdr socket bridge ..."

    if ! command -v socat > /dev/null 2>&1; then
        apt-get update -y
        apt-get install -y socat
        rm -rf /var/lib/apt/lists/*
    fi

    cat << 'EOF' > /usr/local/share/herdr-init.sh
#!/bin/sh

HERDR_BRIDGE_PORT="@HERDR_BRIDGE_PORT@"
HERDR_BRIDGE_SOCKET="/tmp/herdr-bridge.sock"
HERDR_BRIDGE_LOG="/tmp/herdr-bridge.log"

# Best-effort: never let the bridge block or fail container startup. A dead
# host-side LaunchAgent, or a container run outside of a herdr pane, just
# means HERDR_SOCKET_PATH stays unreachable and the hooks that use it no-op,
# same as if this feature weren't installed at all.
if command -v socat > /dev/null 2>&1; then
    rm -f "${HERDR_BRIDGE_SOCKET}"
    (
        while true; do
            socat UNIX-LISTEN:"${HERDR_BRIDGE_SOCKET}",fork,unlink-early,mode=666 \
                TCP:host.docker.internal:"${HERDR_BRIDGE_PORT}" \
                >> "${HERDR_BRIDGE_LOG}" 2>&1
            sleep 1
        done
    ) &
    disown
fi
EOF
    sed -i \
        -e "s|@HERDR_BRIDGE_PORT@|${HERDR_BRIDGE_PORT}|g" \
        /usr/local/share/herdr-init.sh
    chmod +x /usr/local/share/herdr-init.sh

    echo "Done!"
fi
