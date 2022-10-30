#!/usr/bin/env bash

DOCKER_VERSION=${VERSION:-${1:-none}}
DOCKER_COMPOSE_VERSION=${COMPOSE:-${2:-none}}

DOCKER_SHA256=${DOCKER_SHA256:-automatic}
DOCKER_COMPOSE_SHA256=${DOCKER_COMPOSE_SHA256:-automatic}

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

if [[ ${DOCKER_COMPOSE_VERSION} != none ]]; then
    echo "Setup docker-compose v${DOCKER_COMPOSE_VERSION} ..."

    if [[ ${DOCKER_COMPOSE_VERSION} = latest ]]; then
        DOCKER_COMPOSE_VERSION=$(curl -sSL https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name")
    fi

    curl -sSL -o /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)
    chmod +x /usr/local/bin/docker-compose

    if [[ ${DOCKER_COMPOSE_SHA256} = automatic ]]; then
        DOCKER_COMPOSE_SHA256=$(curl -sSL https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m).sha256)
    fi

    if [[ ${DOCKER_COMPOSE_SHA256} != skip ]]; then
        echo "${DOCKER_COMPOSE_SHA256}" | grep "$(sha256sum /usr/local/bin/docker-compose | cut -d ' ' -f 1)"
    fi

    echo "Done!"
fi
