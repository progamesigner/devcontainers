#!/usr/bin/env bash

DOCKER_VERSION=${VERSION:-${1:-latest}}
DOCKER_BUILDX_VERSION=${BUILDX:-${2:-latest}}
DOCKER_COMPOSE_VERSION=${COMPOSE:-${3:-latest}}

DOCKER_SHA256=${DOCKER_SHA256:-automatic}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    dpkg-dev \
    gzip \
"

if [[ ${DOCKER_VERSION} != none ]]; then
    echo "Setup Docker v${DOCKER_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=aarch64;;
        armel) ARCHITECTURE=armel;;
        armhf) ARCHITECTURE=armhf;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${DOCKER_VERSION} = latest ]]; then
        DOCKER_VERSION=$(curl -sSL https://api.github.com/repos/docker/docker/releases/latest | jq -r ".tag_name")
    fi

    DOCKER_VERSION=${DOCKER_VERSION#docker-}
    DOCKER_VERSION=${DOCKER_VERSION#v}

    curl -sSL -o /tmp/docker.tar.gz https://download.docker.com/linux/static/stable/${ARCHITECTURE}/docker-${DOCKER_VERSION}.tgz

    tar -xz -f /tmp/docker.tar.gz -C /usr/local/bin --strip-components=1

    if [[ ${DOCKER_SHA256} = automatic ]]; then
        # Docker doesn't provide any checksum files yet ...
        DOCKER_SHA256="skip"
    fi

    if [[ ${DOCKER_SHA256} != skip ]]; then
        echo "${DOCKER_SHA256}" | grep "$(sha256sum /usr/local/bin/docker | cut -d ' ' -f 1)"
    fi

    rm -rf /tmp/docker.tar.gz

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi

if [[ ${DOCKER_BUILDX_VERSION} != none ]]; then
    echo "Setup docker-buildx v${DOCKER_BUILDX_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=linux-amd64;;
        arm64) ARCHITECTURE=linux-arm64;;
        armel) ARCHITECTURE=linux-arm-v6;;
        armhf) ARCHITECTURE=linux-arm-v7;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${DOCKER_BUILDX_VERSION} = latest ]]; then
        DOCKER_BUILDX_VERSION=$(curl -sSL https://api.github.com/repos/docker/buildx/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${DOCKER_BUILDX_VERSION} != v* ]]; then
        DOCKER_BUILDX_VERSION=v${DOCKER_BUILDX_VERSION}
    fi

    mkdir -p /usr/local/libexec/docker/cli-plugins
    curl -sSL -o /usr/local/libexec/docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/${DOCKER_BUILDX_VERSION}/buildx-${DOCKER_BUILDX_VERSION}.${ARCHITECTURE}
    curl -sSL -o /tmp/docker-buildx.asc https://github.com/docker/buildx/releases/download/${DOCKER_BUILDX_VERSION}/checksums.txt
    chmod +x /usr/local/libexec/docker/cli-plugins/docker-buildx

    cat /tmp/docker-buildx.asc | grep "$(sha256sum /usr/local/libexec/docker/cli-plugins/docker-buildx | cut -d ' ' -f 1)"

    rm -rf /tmp/docker-buildx.asc

    echo "Done!"
fi

if [[ ${DOCKER_COMPOSE_VERSION} != none ]]; then
    echo "Setup docker-compose v${DOCKER_COMPOSE_VERSION} ..."

    if [[ ${DOCKER_COMPOSE_VERSION} = latest ]]; then
        DOCKER_COMPOSE_VERSION=$(curl -sSL https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${DOCKER_COMPOSE_VERSION} != v* ]]; then
        DOCKER_COMPOSE_VERSION=v${DOCKER_COMPOSE_VERSION}
    fi

    mkdir -p /usr/local/libexec/docker/cli-plugins
    curl -sSL -o /usr/local/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)
    curl -sSL -o /tmp/docker-compose.asc https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/checksums.txt
    chmod +x /usr/local/libexec/docker/cli-plugins/docker-compose

    cat /tmp/docker-compose.asc | grep "$(sha256sum /usr/local/libexec/docker/cli-plugins/docker-compose | cut -d ' ' -f 1)"

    rm -rf /tmp/docker-compose.asc

    echo "Done!"
fi
