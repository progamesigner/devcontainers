#!/usr/bin/env bash

ANTIGRAVITY_CLI_VERSION=${VERSION:-${1:-latest}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${ANTIGRAVITY_CLI_VERSION} != none ]]; then
    echo "Setup Antigravity CLI v${ANTIGRAVITY_CLI_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64 ;;
        arm64) ARCHITECTURE=arm64 ;;
        *) echo "unsupported architecture: $(dpkg --print-architecture)"; exit 1 ;;
    esac

    PLATFORM="linux_${ARCHITECTURE}"
    if [[ -f /etc/alpine-release ]]; then
        PLATFORM="${PLATFORM}_musl"
    fi

    MANIFEST_URL=https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/${PLATFORM}.json
    MANIFEST_JSON=$(curl -fsSL "${MANIFEST_URL}")
    parse_manifest_value() {
        local key="$1"
        sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" <<< "${MANIFEST_JSON}"
    }

    LATEST_VERSION=$(parse_manifest_value "version")
    DOWNLOAD_URL=$(parse_manifest_value "url")
    SHA512=$(parse_manifest_value "sha512")
    if [[ -z "${LATEST_VERSION}" || -z "${DOWNLOAD_URL}" || -z "${SHA512}" ]]; then
        echo "Failed to parse the Antigravity CLI release manifest."
        exit 1
    fi

    REQUESTED_VERSION=${ANTIGRAVITY_CLI_VERSION#v}
    if [[ ${ANTIGRAVITY_CLI_VERSION} != latest && ${REQUESTED_VERSION} != "${LATEST_VERSION}" ]]; then
        echo "Antigravity CLI ${ANTIGRAVITY_CLI_VERSION} is unavailable from the official manifest; installing latest (${LATEST_VERSION})."
    fi

    curl -fsSL -o /tmp/antigravity-cli.tar.gz ${DOWNLOAD_URL}
    echo "${SHA512}  /tmp/antigravity-cli.tar.gz" | sha512sum --check --status

    mkdir -p /tmp/antigravity-cli
    tar -xzf /tmp/antigravity-cli.tar.gz -C /tmp/antigravity-cli antigravity

    mkdir -p /usr/local/share/antigravity-cli/bin
    cp -v /tmp/antigravity-cli/antigravity /usr/local/share/antigravity-cli/bin/agy
    chmod +x /usr/local/share/antigravity-cli/bin/agy

    rm -rf /tmp/antigravity-cli /tmp/antigravity-cli.tar.gz

    echo "Antigravity CLI ${LATEST_VERSION} installed."
fi
