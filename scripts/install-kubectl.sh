#!/usr/bin/env bash

KUBECTL_VERSION=${1:-"none"}
KUBECTL_CHECK=${2:-"true"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [ "${KUBECTL_VERSION}" != "none" ]; then
    echo "Extract kubectl ${HUGO_VERSION} ..."

    ARCHITECTURE=""
    case "$(uname -m)" in
        x86_64*) ARCHITECTURE=amd64;;
        aarch64 | armv8*) ARCHITECTURE=arm64;;
        aarch32 | armv7* | armvhf*) ARCHITECTURE=arm;;
        i?86) ARCHITECTURE=386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [ "${KUBECTL_VERSION}" = "current" ]; then
        KUBECTL_VERSION=$(curl -sSL https://dl.k8s.io/release/stable.txt)
    fi

    if [ "${KUBECTL_VERSION::1}" != 'v' ]; then
        KUBECTL_VERSION=v${KUBECTL_VERSION}
    fi

    curl -sSL -o /usr/local/bin/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCHITECTURE}/kubectl
    chmod -v +x /usr/local/bin/kubectl

    if [ "${KUBECTL_CHECK}" = "true" ]; then
        KUBECTL_SHA256=$(curl -sSL https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/${ARCHITECTURE}/kubectl.sha256)
        echo "${KUBECTL_SHA256}" | grep "$(sha256sum /usr/local/bin/kubectl | cut -d ' ' -f 1)"
    fi
fi

echo "Done!"
