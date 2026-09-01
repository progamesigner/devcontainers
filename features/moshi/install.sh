#!/usr/bin/env bash

MOSHI_VERSION=${VERSION:-${1:-latest}}
MOSHI_BRIDGE=${BRIDGE:-${2:-true}}
MOSHI_REMOTE_USER=${REMOTEUSER:-${3:-}}
MOSHI_REMOTE_HOST=${REMOTEHOST:-${4:-host.docker.internal}}
MOSHI_REMOTE_SOCKET_PATH=${REMOTESOCKETPATH:-${5:-/Users/${MOSHI_REMOTE_USER}/Library/Application Support/Moshi/moshi-hook.sock}}
MOSHI_PRIVATE_KEY_PATH=${PRIVATEKEYPATH:-${6:-/var/run/secrets/moshi-devcontainer-bridge/key}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${MOSHI_VERSION} != none ]]; then
    echo "Setup Moshi v${MOSHI_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${MOSHI_VERSION} = latest ]]; then
        MOSHI_VERSION=$(curl -sSL https://cdn.getmoshi.app/hook/latest/version.txt | tr -d '[:space:]')
    fi

    if [[ ${MOSHI_VERSION} != v* ]]; then
        MOSHI_VERSION=v${MOSHI_VERSION}
    fi

    curl -sSL -o /tmp/moshi.tar.gz https://cdn.getmoshi.app/hook/${MOSHI_VERSION}/moshi-hook_Linux_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/moshi.tar.gz.asc https://cdn.getmoshi.app/hook/${MOSHI_VERSION}/checksums.txt

    cat /tmp/moshi.tar.gz.asc | grep "$(sha256sum /tmp/moshi.tar.gz | cut -d ' ' -f 1)"

    tar -xzf /tmp/moshi.tar.gz -C /tmp moshi-hook
    mv /tmp/moshi-hook /usr/local/bin/moshi-hook
    chmod +x /usr/local/bin/moshi-hook

    rm -rf /tmp/moshi.tar.gz /tmp/moshi.tar.gz.asc

    echo "Done!"
fi

cat << 'EOF' > /usr/local/share/moshi-init.sh
#!/bin/sh

set -e
EOF
chmod +x /usr/local/share/moshi-init.sh

if [[ ${MOSHI_BRIDGE} = true && -n ${MOSHI_REMOTE_USER} ]]; then
    mkdir -p /var/{log,run}/moshi-bridge
    chmod 1777 /var/{log,run}/moshi-bridge

    cat << EOF > /usr/local/share/moshi-init.sh
#!/bin/sh

set -e

/usr/local/share/moshi-bridge.sh ${_REMOTE_USER_HOME}/.local/share/moshi
EOF
    chmod +x /usr/local/share/moshi-init.sh

    cat << 'EOF' > /usr/local/bin/moshi-devcontainer
#!/bin/sh

set -e

MOSHI_BRIDGE_DIR=${HOME}/.local/share/moshi
/usr/local/share/moshi-bridge.sh ${MOSHI_BRIDGE_DIR}

export MOSHI_SOCKET_PATH=${MOSHI_BRIDGE_DIR}/moshi-hook.sock

for _ in 1 2 3 4 5; do
    [ -S ${MOSHI_BRIDGE_DIR}/moshi-hook.sock ] && break
    sleep 0.2
done

exec $@
EOF
    chmod +x /usr/local/bin/moshi-devcontainer

    cat << 'EOF' > /usr/local/share/moshi-bridge.sh
#!/bin/sh

set -e

MOSHI_BRIDGE_DIR=$1

MOSHI_PRIVATE_KEY_SRC=@MOSHI_PRIVATE_KEY_PATH@
MOSHI_REMOTE_SOCKET_PATH="@MOSHI_REMOTE_SOCKET_PATH@"
MOSHI_REMOTE_HOST=@MOSHI_REMOTE_HOST@
MOSHI_REMOTE_USER=@MOSHI_REMOTE_USER@

MOSHI_BRIDGE_KEY=/var/run/moshi-bridge/key-$(id -u)
MOSHI_BRIDGE_KNOWN_HOSTS=/var/run/moshi-bridge/known-hosts-$(id -u)
MOSHI_BRIDGE_LOG=/var/log/moshi-bridge/$(id -u).log
MOSHI_BRIDGE_SOCKET=${MOSHI_BRIDGE_DIR}/moshi-hook.sock

command -v ssh > /dev/null 2>&1 || exit 0
[ -S ${MOSHI_BRIDGE_SOCKET} ] && exit 0

mkdir -p ${MOSHI_BRIDGE_DIR}
chmod 777 ${MOSHI_BRIDGE_DIR}

(
    set +e
    while true; do
        set --
        if [ -f ${MOSHI_PRIVATE_KEY_SRC} ]; then
            cp ${MOSHI_PRIVATE_KEY_SRC} ${MOSHI_BRIDGE_KEY} 2>/dev/null && \
            chmod 600 ${MOSHI_BRIDGE_KEY} 2>/dev/null && \
            set -- -i ${MOSHI_BRIDGE_KEY}
        fi

        rm -f ${MOSHI_BRIDGE_SOCKET}
        ssh -N \
            -o BatchMode=yes \
            -o ExitOnForwardFailure=yes \
            -o ServerAliveInterval=15 \
            -o ServerAliveCountMax=3 \
            -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=${MOSHI_BRIDGE_KNOWN_HOSTS} \
            -o StreamLocalBindUnlink=yes \
            $@ \
            -L "${MOSHI_BRIDGE_SOCKET}:${MOSHI_REMOTE_SOCKET_PATH}" \
            ${MOSHI_REMOTE_USER}@${MOSHI_REMOTE_HOST} \
            >> ${MOSHI_BRIDGE_LOG} 2>&1 &
        SSH_PID=$!

        sleep 1
        chmod 666 ${MOSHI_BRIDGE_SOCKET} 2>/dev/null

        wait ${SSH_PID} 2>/dev/null
        sleep 1
    done
) &
EOF
    sed -i \
        -e "s|@MOSHI_REMOTE_USER@|${MOSHI_REMOTE_USER}|g" \
        -e "s|@MOSHI_REMOTE_HOST@|${MOSHI_REMOTE_HOST}|g" \
        -e "s|@MOSHI_REMOTE_SOCKET_PATH@|${MOSHI_REMOTE_SOCKET_PATH}|g" \
        -e "s|@MOSHI_PRIVATE_KEY_PATH@|${MOSHI_PRIVATE_KEY_PATH}|g" \
        /usr/local/share/moshi-bridge.sh
    chmod +x /usr/local/share/moshi-bridge.sh
fi
