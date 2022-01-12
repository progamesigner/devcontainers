#!/usr/bin/env bash

GO_VERSION=${1:-"none"}
GOROOT=${2:-"/usr/local/go"}
GOPATH=${3:-"/opt/go"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    g++ \
    gcc \
    libc6-dev \
    make \
    pkg-config \
"

if [ "${GO_VERSION}" != "none" ]; then
    echo "Setup Go v${GO_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        armhf) ARCHITECTURE=armv6l;;
        i386) ARCHITECTURE=386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/go.tar.gz https://golang.org/dl/go${GO_VERSION}.linux-${ARCHITECTURE}.tar.gz

    mkdir -p ${GOROOT}
    tar -xz -f /tmp/go.tar.gz -C ${GOROOT} --strip-components=1

    mkdir -p ${GOPATH}
    chmod a+rwx ${GOPATH}

    rm -rf /tmp/go.tar.gz

    echo "export GOPATH=${GOPATH}" >> /etc/bash.bashrc
    echo "export GOROOT=${GOROOT}" >> /etc/bash.bashrc
    echo "if [[ "\${PATH}" != *"\${GOPATH}/bin"* ]]; then export PATH="\${GOPATH}/bin:\${PATH}"; fi" >> /etc/bash.bashrc
    echo "if [[ "\${PATH}" != *"\${GOROOT}/bin"* ]]; then export PATH="\${GOROOT}/bin:\${PATH}"; fi" >> /etc/bash.bashrc

    echo "Done!"
fi
