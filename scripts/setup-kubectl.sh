#!/usr/bin/env bash

KUBECTL_VERSION=${1:-"none"}
KUBECTL_SHA256=${2:-"automatic"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [ "${KUBECTL_VERSION}" != "none" ]; then
    echo "Setup kubectl v${HUGO_VERSION} ..."

    ARCHITECTURE=""
    case "$(uname -m)" in
        x86_64*) ARCHITECTURE=amd64;;
        aarch64|armv8*) ARCHITECTURE=arm64;;
        aarch32|armv7*|armvhf*) ARCHITECTURE=arm;;
        i?86) ARCHITECTURE=386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [ "${KUBECTL_VERSION}" = "latest" ]; then
        KUBECTL_VERSION=$(curl -sSL https://api.github.com/repos/kubernetes/kubernetes/releases/latest | jq -r ".tag_name")
    fi

    if [ "${KUBECTL_VERSION::1}" != "v" ]; then
        KUBECTL_VERSION=v${KUBECTL_VERSION}
    fi

    curl -sSL -o /usr/local/bin/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCHITECTURE}/kubectl
    chmod -v +x /usr/local/bin/kubectl

    if [ "${KUBECTL_SHA256}" = "automatic" ]; then
        KUBECTL_SHA256=$(curl -sSL https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/${ARCHITECTURE}/kubectl.sha256)
    fi

    if [ "${KUBECTL_SHA256}" != "skip" ]; then
        echo "${KUBECTL_SHA256}" | grep "$(sha256sum /usr/local/bin/kubectl | cut -d ' ' -f 1)"
    fi
fi

echo "Done!"
