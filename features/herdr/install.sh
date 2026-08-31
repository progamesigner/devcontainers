#!/usr/bin/env bash

HERDR_VERSION=${VERSION:-${1:-latest}}
HERDR_BRIDGE=${BRIDGE:-${2:-true}}
HERDR_REMOTE_USER=${REMOTEUSER:-${3:-}}
HERDR_REMOTE_HOST=${REMOTEHOST:-${4:-host.docker.internal}}
HERDR_PRIVATE_KEY_PATH=${PRIVATEKEYPATH:-${5:-/var/run/secrets/herdr-devcontainer-bridge/key}}

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

cat << 'EOF' > /usr/local/share/herdr-init.sh
#!/bin/sh

set -e
EOF
chmod +x /usr/local/share/herdr-init.sh

if [[ ${HERDR_BRIDGE} = true && -n ${HERDR_REMOTE_USER} ]]; then
    mkdir -p /var/{log,run}/herdr-bridge
    chmod 1777 /var/{log,run}/herdr-bridge

    cat << EOF > /usr/local/share/herdr-init.sh
#!/bin/sh

set -e

/usr/local/share/herdr-bridge.sh ${_REMOTE_USER_HOME}/.config/herdr "~/.config/herdr/herdr.sock"
EOF
    chmod +x /usr/local/share/herdr-init.sh

    cat << 'EOF' > /usr/local/bin/herdr-devcontainer
#!/bin/sh

set -e

HERDR_SESSION=${HERDR_SESSION:-}
if [ -n "${HERDR_SESSION}" ]; then
    HERDR_BRIDGE_DIR=${HOME}/.config/herdr/sessions/${HERDR_SESSION}
    /usr/local/share/herdr-bridge.sh ${HERDR_BRIDGE_DIR} "~/.config/herdr/sessions/${HERDR_SESSION}/herdr.sock"
else
    HERDR_BRIDGE_DIR=${HOME}/.config/herdr
    /usr/local/share/herdr-bridge.sh ${HERDR_BRIDGE_DIR} "~/.config/herdr/herdr.sock"
fi

export HERDR_ENV=1
export HERDR_SOCKET_PATH=${HERDR_BRIDGE_DIR}/herdr.sock

for _ in 1 2 3 4 5; do
    [ -S ${HERDR_BRIDGE_DIR}/herdr.sock ] && break
    sleep 0.2
done

exec $@
EOF
    chmod +x /usr/local/bin/herdr-devcontainer

    cat << 'EOF' > /usr/local/share/herdr-bridge.sh
#!/bin/sh

set -e

HERDR_BRIDGE_DIR=$1
HERDR_BRIDGE_REMOTE=$2

HERDR_PRIVATE_KEY_SRC=@HERDR_PRIVATE_KEY_PATH@
HERDR_REMOTE_HOST=@HERDR_REMOTE_HOST@
HERDR_REMOTE_USER=@HERDR_REMOTE_USER@

HERDR_BRIDGE_KEY=/var/run/herdr-bridge/key-$(id -u)
HERDR_BRIDGE_KNOWN_HOSTS=/var/run/herdr-bridge/known-hosts-$(id -u)
HERDR_BRIDGE_LOG=/var/log/herdr-bridge/$(id -u).log
HERDR_BRIDGE_SOCKET=${HERDR_BRIDGE_DIR}/herdr.sock

command -v ssh > /dev/null 2>&1 || exit 0
[ -S ${HERDR_BRIDGE_SOCKET} ] && exit 0

mkdir -p ${HERDR_BRIDGE_DIR}
chmod 777 ${HERDR_BRIDGE_DIR}

(
    set +e
    while true; do
        set --
        if [ -f ${HERDR_PRIVATE_KEY_SRC} ]; then
            cp ${HERDR_PRIVATE_KEY_SRC} ${HERDR_BRIDGE_KEY} 2>/dev/null \
                && chmod 600 ${HERDR_BRIDGE_KEY} 2>/dev/null \
                && set -- -i ${HERDR_BRIDGE_KEY}
        fi

        rm -f ${HERDR_BRIDGE_SOCKET}
        ssh -N \
            -o BatchMode=yes \
            -o ExitOnForwardFailure=yes \
            -o ServerAliveInterval=15 \
            -o ServerAliveCountMax=3 \
            -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=${HERDR_BRIDGE_KNOWN_HOSTS} \
            -o StreamLocalBindUnlink=yes \
            $@ \
            -L ${HERDR_BRIDGE_SOCKET}:${HERDR_BRIDGE_REMOTE} \
            ${HERDR_REMOTE_USER}@${HERDR_REMOTE_HOST} \
            >> ${HERDR_BRIDGE_LOG} 2>&1 &
        SSH_PID=$!

        sleep 1
        chmod 666 ${HERDR_BRIDGE_SOCKET} 2>/dev/null

        wait ${SSH_PID} 2>/dev/null
        sleep 1
    done
) &
EOF
    sed -i \
        -e "s|@HERDR_REMOTE_USER@|${HERDR_REMOTE_USER}|g" \
        -e "s|@HERDR_REMOTE_HOST@|${HERDR_REMOTE_HOST}|g" \
        -e "s|@HERDR_PRIVATE_KEY_PATH@|${HERDR_PRIVATE_KEY_PATH}|g" \
        /usr/local/share/herdr-bridge.sh
    chmod +x /usr/local/share/herdr-bridge.sh
fi
