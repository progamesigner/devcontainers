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

# Bridge the host's herdr Unix socket(s) into the container over SSH.
#
# On Docker Desktop/OrbStack-style setups the container runs in a separate
# VM/kernel from the host, so a bind-mounted copy of the host's herdr.sock
# is just a stale file — connecting to it returns ECONNREFUSED, since a Unix
# domain socket is a live kernel object, not just file bytes. OpenSSH's
# `-L localsocket:remotesocket` forwards an actual Unix-socket-to-Unix-socket
# tunnel over the ssh connection, which does cross the boundary. `~` in the
# remote path is resolved server-side (sshd expands it against the
# authenticated user's home directory) — confirmed live: a garbage remote
# path is rejected by the local ssh client before it even connects, but
# `~/.config/herdr/herdr.sock` is accepted and passed through to the server.
# This needs Remote Login (sshd) enabled on the macOS host — see
# https://gist.github.com/progamesigner/0f90551cabaaf54ccc8407fe9944c9c9
# for a walkthrough (a dedicated, forwarding-only key is recommended there,
# but see below: it is not required).
#
# The private key is OPTIONAL. `privateKeyPath` is only used if a file
# actually exists there at container start; if not, ssh is invoked without
# `-i` and falls back to whatever auth is otherwise available (an agent
# forwarded via SSH_AUTH_SOCK, a default ~/.ssh/id_* the image happens to
# have, etc.) — same best-effort story as everything else here: no working
# auth just means HERDR_SOCKET_PATH stays unreachable and the hooks that use
# it no-op. `-o BatchMode=yes` guarantees this fails fast instead of hanging
# on a password prompt, and the key file is (re-)checked every retry
# iteration, not just once at container start, so mounting a key in later
# gets picked up without recreating the container.
#
# Sockets are bridged to inside the container's own
# `<remote-user-home>/.config/herdr/`, mirroring the host's own default
# layout — not some throwaway /tmp path — so anything that resolves herdr's
# default socket path itself (the `herdr` CLI's own client mode, not just
# these hooks) finds it with no HERDR_SOCKET_PATH override needed. The
# actual container user's home directory has to be resolved at container
# build time via `_REMOTE_USER_HOME` (baked in below) rather than read as
# `$HOME` inside the entrypoint script, because the entrypoint may run as
# root regardless of which user `docker exec` sessions run as — `$HOME`
# would then resolve to /root, not the real dev user's home.
#
# HERDR_SESSIONS (a comma-separated list of herdr named-session names, from
# `herdr --session <name>`) is read directly from the container's own
# runtime environment inside the entrypoint script — it is NOT a Feature
# option baked in at image build time. Set it in your docker-compose.yml's
# `environment:` for the dev container service (or devcontainer.json's own
# top-level `containerEnv`/`remoteEnv`) and it takes effect on container
# recreate, with no image rebuild needed. Each named session bridges to its
# own <home>/.config/herdr/sessions/<name>/herdr.sock; the default/unnamed
# session is always bridged to <home>/.config/herdr/herdr.sock regardless.
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
HERDR_CONTAINER_HOME="@HERDR_CONTAINER_HOME@"
HERDR_PRIVATE_KEY="/tmp/herdr-bridge-key"
HERDR_BRIDGE_DIR="${HERDR_CONTAINER_HOME}/.config/herdr"
HERDR_BRIDGE_KNOWN_HOSTS="/tmp/herdr-bridge-known-hosts"
HERDR_BRIDGE_LOG="/tmp/herdr-bridge.log"

# Best-effort: never let the bridge block or fail container startup.
if ! command -v ssh > /dev/null 2>&1; then
    exit 0
fi

mkdir -p "${HERDR_BRIDGE_DIR}"
chmod 777 "${HERDR_BRIDGE_DIR}"

(
    while true; do
        set --
        if [ -f "${HERDR_PRIVATE_KEY_SRC}" ]; then
            cp "${HERDR_PRIVATE_KEY_SRC}" "${HERDR_PRIVATE_KEY}" 2>/dev/null \
                && chmod 600 "${HERDR_PRIVATE_KEY}" 2>/dev/null \
                && set -- -i "${HERDR_PRIVATE_KEY}"
        fi

        rm -f "${HERDR_BRIDGE_DIR}/herdr.sock"
        set -- "$@" -L "${HERDR_BRIDGE_DIR}/herdr.sock:~/.config/herdr/herdr.sock"
        SOCKET_PATHS="${HERDR_BRIDGE_DIR}/herdr.sock"

        OLD_IFS="${IFS}"
        IFS=","
        for raw_name in ${HERDR_SESSIONS:-}; do
            IFS="${OLD_IFS}"
            # trim leading/trailing whitespace, so "work, personal" (space
            # after the comma) doesn't end up as a literal " personal"
            # socket path
            name="${raw_name#"${raw_name%%[![:space:]]*}"}"
            name="${name%"${name##*[![:space:]]}"}"
            [ -n "${name}" ] || continue
            mkdir -p "${HERDR_BRIDGE_DIR}/sessions/${name}"
            chmod 777 "${HERDR_BRIDGE_DIR}/sessions/${name}"
            rm -f "${HERDR_BRIDGE_DIR}/sessions/${name}/herdr.sock"
            set -- "$@" -L "${HERDR_BRIDGE_DIR}/sessions/${name}/herdr.sock:~/.config/herdr/sessions/${name}/herdr.sock"
            SOCKET_PATHS="${SOCKET_PATHS} ${HERDR_BRIDGE_DIR}/sessions/${name}/herdr.sock"
            IFS=","
        done
        IFS="${OLD_IFS}"

        ssh -N \
            -o BatchMode=yes \
            -o ExitOnForwardFailure=yes \
            -o ServerAliveInterval=15 \
            -o ServerAliveCountMax=3 \
            -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile="${HERDR_BRIDGE_KNOWN_HOSTS}" \
            -o StreamLocalBindUnlink=yes \
            "$@" \
            "${HERDR_REMOTE_USER}@${HERDR_REMOTE_HOST}" \
            >> "${HERDR_BRIDGE_LOG}" 2>&1 &
        SSH_PID=$!

        # The entrypoint may run as root regardless of which (non-root) user
        # later `docker exec` sessions run as; ssh creates each local socket
        # owned by whoever ran it, so without this those sessions would get
        # EACCES connecting to a root-owned, ssh-default-mode socket.
        sleep 1
        for path in ${SOCKET_PATHS}; do
            chmod 666 "${path}" 2>/dev/null
        done

        wait "${SSH_PID}" 2>/dev/null
        sleep 1
    done
) &
EOF
    sed -i \
        -e "s|@HERDR_REMOTE_USER@|${HERDR_REMOTE_USER}|g" \
        -e "s|@HERDR_REMOTE_HOST@|${HERDR_REMOTE_HOST}|g" \
        -e "s|@HERDR_PRIVATE_KEY_PATH@|${HERDR_PRIVATE_KEY_PATH}|g" \
        -e "s|@HERDR_CONTAINER_HOME@|${_REMOTE_USER_HOME}|g" \
        /usr/local/share/herdr-init.sh
    chmod +x /usr/local/share/herdr-init.sh

    echo "Done!"
fi
