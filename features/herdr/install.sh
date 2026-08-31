#!/usr/bin/env bash

HERDR_VERSION=${VERSION:-${1:-latest}}
HERDR_BRIDGE=${BRIDGE:-${2:-true}}
HERDR_REMOTE_USER=${REMOTEUSER:-${3:-}}
HERDR_REMOTE_HOST=${REMOTEHOST:-${4:-host.docker.internal}}
HERDR_PRIVATE_KEY_PATH=${PRIVATEKEYPATH:-${5:-/run/secrets/herdr_bridge_key}}

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

# The feature always declares this path as its entrypoint (devcontainer.json
# doesn't support conditional entrypoints), so a placeholder must exist even
# when the bridge below is skipped — otherwise container start fails looking
# for a file that was never written.
cat << 'EOF' > /usr/local/share/herdr-init.sh
#!/bin/sh
# herdr socket bridge disabled: no remoteUser was set, or bridge=false.
EOF
chmod +x /usr/local/share/herdr-init.sh

# Bridge the host's HERDR_SOCKET_PATH Unix socket into the container over SSH.
#
# On Docker Desktop/OrbStack-style setups the container runs in a separate
# VM/kernel from the host, so a bind-mounted copy of the host's herdr.sock
# is just a stale file — connecting to it returns ECONNREFUSED, since a Unix
# domain socket is a live kernel object, not just file bytes. OpenSSH's
# `-L localsocket:remotesocket` forwards an actual Unix-socket-to-Unix-socket
# tunnel over the ssh connection, which does cross the boundary. This needs
# Remote Login (sshd) enabled on the macOS host, plus a dedicated,
# forwarding-only key — see
# https://gist.github.com/progamesigner/0f90551cabaaf54ccc8407fe9944c9c9
# for how to generate and restrict it, and how to bind-mount the private key
# into the container at privateKeyPath.
if [[ ${HERDR_BRIDGE} = true && -n ${HERDR_REMOTE_USER} ]]; then
    echo "Setup Herdr socket bridge ..."

    if ! command -v ssh > /dev/null 2>&1; then
        apt-get update -y
        apt-get install -y openssh-client
        rm -rf /var/lib/apt/lists/*
    fi

    cat << 'EOF' > /usr/local/share/herdr-init.sh
#!/bin/sh

HERDR_REMOTE_USER="@HERDR_REMOTE_USER@"
HERDR_REMOTE_HOST="@HERDR_REMOTE_HOST@"
HERDR_PRIVATE_KEY_SRC="@HERDR_PRIVATE_KEY_PATH@"
HERDR_PRIVATE_KEY="/tmp/herdr-bridge-key"
HERDR_BRIDGE_SOCKET="/tmp/herdr-bridge.sock"
HERDR_BRIDGE_KNOWN_HOSTS="/tmp/herdr-bridge-known-hosts"
HERDR_BRIDGE_LOG="/tmp/herdr-bridge.log"

# Best-effort: never let the bridge block or fail container startup. A
# missing/unreadable private key, or a container run outside of a herdr
# pane, just means HERDR_SOCKET_PATH stays unreachable and the hooks that
# use it no-op, same as if this feature weren't installed at all.
if command -v ssh > /dev/null 2>&1 && [ -f "${HERDR_PRIVATE_KEY_SRC}" ]; then
    cp "${HERDR_PRIVATE_KEY_SRC}" "${HERDR_PRIVATE_KEY}"
    chmod 600 "${HERDR_PRIVATE_KEY}"
    rm -f "${HERDR_BRIDGE_SOCKET}"
    (
        while true; do
            ssh -N \
                -o ExitOnForwardFailure=yes \
                -o ServerAliveInterval=15 \
                -o ServerAliveCountMax=3 \
                -o StrictHostKeyChecking=accept-new \
                -o UserKnownHostsFile="${HERDR_BRIDGE_KNOWN_HOSTS}" \
                -o StreamLocalBindUnlink=yes \
                -i "${HERDR_PRIVATE_KEY}" \
                -L "${HERDR_BRIDGE_SOCKET}:/Users/${HERDR_REMOTE_USER}/.config/herdr/herdr.sock" \
                "${HERDR_REMOTE_USER}@${HERDR_REMOTE_HOST}" \
                >> "${HERDR_BRIDGE_LOG}" 2>&1
            sleep 1
        done
    ) &
    disown
fi
EOF
    sed -i \
        -e "s|@HERDR_REMOTE_USER@|${HERDR_REMOTE_USER}|g" \
        -e "s|@HERDR_REMOTE_HOST@|${HERDR_REMOTE_HOST}|g" \
        -e "s|@HERDR_PRIVATE_KEY_PATH@|${HERDR_PRIVATE_KEY_PATH}|g" \
        /usr/local/share/herdr-init.sh
    chmod +x /usr/local/share/herdr-init.sh

    echo "Done!"
fi
