#!/usr/bin/env bash

KUBECTL_VERSION=${VERSION:-${1:-none}}

KUBECTL_SHA256=${KUBECTL_SHA256:-automatic}

set -e

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${KUBECTL_VERSION} != none ]]; then
    echo "Setup kubectl v${KUBECTL_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        armel|armhf) ARCHITECTURE=arm;;
        i386) ARCHITECTURE=386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${KUBECTL_VERSION} = latest ]]; then
        KUBECTL_VERSION=$(curl -sSL https://api.github.com/repos/kubernetes/kubernetes/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${KUBECTL_VERSION} != v* ]]; then
        KUBECTL_VERSION=v${KUBECTL_VERSION}
    fi

    curl -sSL -o /usr/local/bin/kubectl https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCHITECTURE}/kubectl
    chmod +x /usr/local/bin/kubectl

    if [[ ${KUBECTL_SHA256} = automatic ]]; then
        KUBECTL_SHA256=$(curl -sSL https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/${ARCHITECTURE}/kubectl.sha256)
    fi

    if [[ ${KUBECTL_SHA256} != skip ]]; then
        echo "${KUBECTL_SHA256}" | grep "$(sha256sum /usr/local/bin/kubectl | cut -d ' ' -f 1)"
    fi

    echo "Done!"
fi
