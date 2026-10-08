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

    if [ -f /etc/alpine-release ]; then
        ARCHITECTURE=${ARCHITECTURE}-musl
    fi

    PACKAGE_SCOPE=@opencode
    if [[ ${OPENCODE_VERSION} = latest ]]; then
        OPENCODE_METADATA=$(curl -sSL https://opencode.ai/update/api/latest/cli/npm)
        OPENCODE_VERSION=$(jq -r ".version" <<< "${OPENCODE_METADATA}")
        PACKAGE_SCOPE=$(jq -r ".metadata.package" <<< "${OPENCODE_METADATA}")
        PACKAGE_SCOPE=${PACKAGE_SCOPE%/cli}
    fi

    OPENCODE_VERSION=${OPENCODE_VERSION#v}

    # Older releases were published under the previous package scope
    for SCOPE in ${PACKAGE_SCOPE} @opencode-ai; do
        PACKAGE_JSON=$(curl -sSL https://registry.npmjs.org/${SCOPE}%2fcli-linux-${ARCHITECTURE}/${OPENCODE_VERSION})
        if jq -e ".dist.tarball" <<< "${PACKAGE_JSON}" > /dev/null 2>&1; then
            break
        fi
    done

    if ! jq -e ".dist.tarball" <<< "${PACKAGE_JSON}" > /dev/null 2>&1; then
        echo "OpenCode v${OPENCODE_VERSION} is not available for linux-${ARCHITECTURE}"
        exit 1
    fi

    curl -sSL -o /tmp/opencode.tgz $(jq -r ".dist.tarball" <<< "${PACKAGE_JSON}")

    SHA512=$(jq -r ".dist.integrity | ltrimstr(\"sha512-\")" <<< "${PACKAGE_JSON}" | base64 -d | od -An -v -tx1 | tr -d ' \n')
    echo "${SHA512}  /tmp/opencode.tgz" | sha512sum --check --status

    mkdir -p /tmp/opencode
    tar -xz -f /tmp/opencode.tgz -C /tmp/opencode

    mkdir -p /usr/local/share/opencode/bin
    cp -v /tmp/opencode/package/bin/opencode /usr/local/share/opencode/bin/opencode
    chmod +x /usr/local/share/opencode/bin/opencode

    rm -rf /tmp/opencode /tmp/opencode.tgz

    echo "Done!"
fi
