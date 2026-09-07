#!/usr/bin/env bash

MOSHI_VERSION=${VERSION:-${1:-latest}}
MOSHI_BRIDGE=${BRIDGE:-${2:-true}}
MOSHI_REMOTE_USER=${REMOTEUSER:-${3:-}}
MOSHI_REMOTE_HOST=${REMOTEHOST:-${4:-host.docker.internal}}
MOSHI_REMOTE_SOCKET_PATH=${REMOTESOCKETPATH:-${5:-/Users/${MOSHI_REMOTE_USER}/Library/Application Support/Moshi/moshi-hook.sock}}
MOSHI_PRIVATE_KEY_PATH=${PRIVATEKEYPATH:-${6:-/var/run/secrets/moshi-devcontainer-bridge/key}}
MOSHI_CLIPBOARD=${CLIPBOARD:-${7:-false}}
MOSHI_CLIPBOARD_WATCH_PATH=${CLIPBOARDWATCHPATH:-${8:-}}
MOSHI_CLIPBOARD_DISPLAY_BASE=100

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

MOSHI_BRIDGE_DIR=${MOSHI_BRIDGE_DIR:-@MOSHI_USER_HOME@/.local/share/moshi}

if [ -x /usr/local/share/moshi-bridge.sh ]; then
    /usr/local/share/moshi-bridge.sh "${MOSHI_BRIDGE_DIR}"
    export MOSHI_SOCKET_PATH="${MOSHI_BRIDGE_DIR}/moshi-hook.sock"
fi

if [ -x /usr/local/share/moshi-clipboard.sh ]; then
    /usr/local/share/moshi-clipboard.sh
    export DISPLAY=${DISPLAY:-:$(( @MOSHI_CLIPBOARD_DISPLAY_BASE@ + $(id -u) ))}
fi
EOF
sed -i \
    -e "s|@MOSHI_USER_HOME@|${_REMOTE_USER_HOME:-/root}|g" \
    -e "s|@MOSHI_CLIPBOARD_DISPLAY_BASE@|${MOSHI_CLIPBOARD_DISPLAY_BASE}|g" \
    /usr/local/share/moshi-init.sh
chmod +x /usr/local/share/moshi-init.sh

cat << 'EOF' > /usr/local/bin/moshi-devcontainer
#!/bin/sh

set -e

MOSHI_BRIDGE_DIR=${HOME}/.local/share/moshi
. /usr/local/share/moshi-init.sh

if [ -x /usr/local/share/moshi-bridge.sh ]; then
    for _ in 1 2 3 4 5; do
        [ -S "${MOSHI_SOCKET_PATH}" ] && break
        sleep 0.2
    done
fi

exec "$@"
EOF
chmod +x /usr/local/bin/moshi-devcontainer

if [[ ${MOSHI_BRIDGE} = true && -n ${MOSHI_REMOTE_USER} ]]; then
    mkdir -p /var/{log,run}/moshi-bridge
    chmod 1777 /var/{log,run}/moshi-bridge

    cat << 'EOF' > /usr/local/share/moshi-bridge.sh
#!/bin/sh

set -e

if [ -z "${MOSHI_BRIDGE_SETSID:-}" ] && command -v setsid > /dev/null 2>&1; then
    MOSHI_BRIDGE_SETSID=1 exec setsid "$0" "$@"
fi

MOSHI_BRIDGE_DIR=$1

MOSHI_PRIVATE_KEY_SRC=@MOSHI_PRIVATE_KEY_PATH@
MOSHI_REMOTE_SOCKET_PATH="@MOSHI_REMOTE_SOCKET_PATH@"
MOSHI_REMOTE_HOST=@MOSHI_REMOTE_HOST@
MOSHI_REMOTE_USER=@MOSHI_REMOTE_USER@

MOSHI_BRIDGE_KEY=/var/run/moshi-bridge/key-$(id -u)
MOSHI_BRIDGE_KNOWN_HOSTS=/var/run/moshi-bridge/known-hosts-$(id -u)
MOSHI_BRIDGE_LOG=/var/log/moshi-bridge/$(id -u).log
MOSHI_BRIDGE_PID=/var/run/moshi-bridge/bridge-$(id -u).pid
MOSHI_BRIDGE_SOCKET=${MOSHI_BRIDGE_DIR}/moshi-hook.sock

command -v ssh > /dev/null 2>&1 || exit 0

MOSHI_BRIDGE_LAST_PID=$(cat ${MOSHI_BRIDGE_PID} 2>/dev/null || true)
if [ -n "${MOSHI_BRIDGE_LAST_PID}" ] && \
   kill -0 "${MOSHI_BRIDGE_LAST_PID}" 2>/dev/null && \
   grep -qsa moshi-bridge.sh /proc/"${MOSHI_BRIDGE_LAST_PID}"/cmdline; then
    exit 0
fi
rm -f ${MOSHI_BRIDGE_PID} ${MOSHI_BRIDGE_SOCKET}

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
echo $! > ${MOSHI_BRIDGE_PID}
EOF
    sed -i \
        -e "s|@MOSHI_REMOTE_USER@|${MOSHI_REMOTE_USER}|g" \
        -e "s|@MOSHI_REMOTE_HOST@|${MOSHI_REMOTE_HOST}|g" \
        -e "s|@MOSHI_REMOTE_SOCKET_PATH@|${MOSHI_REMOTE_SOCKET_PATH}|g" \
        -e "s|@MOSHI_PRIVATE_KEY_PATH@|${MOSHI_PRIVATE_KEY_PATH}|g" \
        /usr/local/share/moshi-bridge.sh
    chmod +x /usr/local/share/moshi-bridge.sh
fi

if [[ ${MOSHI_CLIPBOARD} = true ]]; then
    echo "Setup Moshi clipboard ..."

    apt-get update
    apt-get install --no-install-recommends --yes \
        imagemagick \
        inotify-tools \
        xclip \
        xvfb
    rm -rf /var/lib/apt/lists/*

    mkdir -p /var/{log,run}/moshi-clipboard
    chmod 1777 /var/{log,run}/moshi-clipboard

    cat << 'EOF' > /usr/local/share/moshi-clipboard.sh
#!/bin/sh

set -e

if [ -z "${MOSHI_CLIPBOARD_SETSID:-}" ] && command -v setsid > /dev/null 2>&1; then
    MOSHI_CLIPBOARD_SETSID=1 exec setsid "$0" "$@"
fi

MOSHI_CLIPBOARD_DISPLAY=:$(( @MOSHI_CLIPBOARD_DISPLAY_BASE@ + $(id -u) ))
MOSHI_CLIPBOARD_WATCH_PATH="@MOSHI_CLIPBOARD_WATCH_PATH@"

MOSHI_CLIPBOARD_LOG=/var/log/moshi-clipboard/$(id -u).log
MOSHI_CLIPBOARD_OWNER=/var/run/moshi-clipboard/owner-$(id -u).pid
MOSHI_CLIPBOARD_LOCK=/var/run/moshi-clipboard/lock-$(id -u)

command -v Xvfb > /dev/null 2>&1 || exit 0
command -v xclip > /dev/null 2>&1 || exit 0

mkdir ${MOSHI_CLIPBOARD_LOCK} 2>/dev/null || exit 0

convert_to_png() {
    if command -v magick > /dev/null 2>&1; then
        magick "$1" png:-
    else
        convert "$1" png:-
    fi
}

serve_clipboard() {
    if [ -f ${MOSHI_CLIPBOARD_OWNER} ]; then
        kill "$(cat ${MOSHI_CLIPBOARD_OWNER})" 2>/dev/null || true
        rm -f ${MOSHI_CLIPBOARD_OWNER}
    fi
    convert_to_png "$1" | xclip -display ${MOSHI_CLIPBOARD_DISPLAY} -selection clipboard -t image/png -i &
    echo $! > ${MOSHI_CLIPBOARD_OWNER}
}

(
    set +e

    while true; do
        Xvfb ${MOSHI_CLIPBOARD_DISPLAY} -screen 0 1x1x24 >> ${MOSHI_CLIPBOARD_LOG} 2>&1 &
        XVFB_PID=$!

        sleep 1

        if [ -n "${MOSHI_CLIPBOARD_WATCH_PATH}" ] && [ -d "${MOSHI_CLIPBOARD_WATCH_PATH}" ]; then
            inotifywait -q -m -e close_write -e moved_to --format '%f' "${MOSHI_CLIPBOARD_WATCH_PATH}" 2>>${MOSHI_CLIPBOARD_LOG} |
            while read -r name; do
                case "${name}" in
                    moshi-paste-*) serve_clipboard "${MOSHI_CLIPBOARD_WATCH_PATH}/${name}" ;;
                esac
            done
        fi

        wait ${XVFB_PID} 2>/dev/null
        sleep 1
    done
) &
EOF
    sed -i \
        -e "s|@MOSHI_CLIPBOARD_DISPLAY_BASE@|${MOSHI_CLIPBOARD_DISPLAY_BASE}|g" \
        -e "s|@MOSHI_CLIPBOARD_WATCH_PATH@|${MOSHI_CLIPBOARD_WATCH_PATH}|g" \
        /usr/local/share/moshi-clipboard.sh
    chmod +x /usr/local/share/moshi-clipboard.sh
fi
