#!/usr/bin/env bash

KUBECTL_VERSION=${KUBECTL:-${1:-latest}}
KUSTOMIZE_VERSION=${KUSTOMIZE:-${2:-latest}}
HELM_VERSION=${HELM:-${3:-latest}}

KUBECTL_SHA256=${KUBECTL_SHA256:-automatic}
HELM_SHA256=${HELM_SHA256:-automatic}

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

if [[ ${KUSTOMIZE_VERSION} != none ]]; then
    echo "Setup Kustomize v${KUSTOMIZE_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${KUSTOMIZE_VERSION} = latest ]]; then
        KUSTOMIZE_VERSION=$(curl -sSL https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest | jq -r ".tag_name | sub(\"kustomize/\"; \"\")")
    fi

    if [[ ${KUSTOMIZE_VERSION} != v* ]]; then
        KUSTOMIZE_VERSION=v${KUSTOMIZE_VERSION}
    fi

    curl -sSL -o /tmp/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/kustomize.tar.gz.asc https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/checksums.txt

    cat /tmp/kustomize.tar.gz.asc | grep "$(sha256sum /tmp/kustomize.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/kustomize
    tar -xz -f /tmp/kustomize.tar.gz -C /tmp/kustomize
    cp -v /tmp/kustomize/kustomize /usr/local/bin/kustomize
    chmod +x /usr/local/bin/kustomize

    rm -rf /tmp/kustomize.tar.gz /tmp/kustomize.tar.gz.asc /tmp/kustomize

    echo "Done!"
fi

if [[ ${HELM_VERSION} != none ]]; then
    echo "Setup Helm v${HELM_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        armel|armhf) ARCHITECTURE=arm;;
        i386) ARCHITECTURE=386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${HELM_VERSION} = latest ]]; then
        HELM_VERSION=$(curl -sSL https://api.github.com/repos/helm/helm/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${HELM_VERSION} != v* ]]; then
        HELM_VERSION=v${HELM_VERSION}
    fi

    curl -sSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/helm.tar.gz.asc https://github.com/helm/helm/releases/download/${HELM_VERSION}/helm-${HELM_VERSION}-linux-${ARCHITECTURE}.tar.gz.asc
    curl -sSL -o /tmp/helm.tar.gz.sha256 https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCHITECTURE}.tar.gz.sha256
    curl -sSL -o /tmp/helm.tar.gz.sha256.asc https://github.com/helm/helm/releases/download/${HELM_VERSION}/helm-${HELM_VERSION}-linux-${ARCHITECTURE}.tar.gz.sha256.asc

    export GNUPGHOME=$(mktemp -d)
    curl -sSL https://raw.githubusercontent.com/helm/helm/main/KEYS | gpg --import
    gpg --batch --verify /tmp/helm.tar.gz.asc /tmp/helm.tar.gz
    gpg --batch --verify /tmp/helm.tar.gz.sha256.asc /tmp/helm.tar.gz.sha256
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    if [[ ${HELM_SHA256} = automatic ]]; then
        HELM_SHA256=$(cat /tmp/helm.tar.gz.sha256)
    fi

    echo $HELM_SHA256
    if [[ ${HELM_SHA256} != skip ]]; then
        echo "${HELM_SHA256}" | grep "$(sha256sum /tmp/helm.tar.gz | cut -d ' ' -f 1)"
    fi

    mkdir -p /tmp/helm
    tar -xz -f /tmp/helm.tar.gz -C /tmp/helm
    cp -v /tmp/helm/linux-${ARCHITECTURE}/helm /usr/local/bin/helm
    chmod +x /usr/local/bin/helm

    rm -rf /tmp/helm.tar.gz /tmp/helm.tar.gz.asc /tmp/helm.tar.gz.sha256 /tmp/helm.tar.gz.sha256.asc /tmp/helm

    echo "Done!"
fi
