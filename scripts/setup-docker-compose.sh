#!/usr/bin/env bash

DOCKER_COMPOSE_VERSION=${1:-"none"}
DOCKER_COMPOSE_SHA256=${2:-"automatic"}

set -e

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [ "${DOCKER_COMPOSE_VERSION}" != "none" ]; then
    echo "Setup docker-compose v${DOCKER_COMPOSE_VERSION} ..."

    if [ "${DOCKER_COMPOSE_VERSION}" = "latest" ]; then
        DOCKER_COMPOSE_VERSION=$(curl -sSL https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name")
    fi

    curl -sSL -o /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)
    chmod +x /usr/local/bin/docker-compose

    if [ "${DOCKER_COMPOSE_SHA256}" = "automatic" ]; then
        DOCKER_COMPOSE_SHA256=$(curl -sSL https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m).sha256)
    fi

    if [ "${DOCKER_COMPOSE_SHA256}" != "skip" ]; then
        echo "${DOCKER_COMPOSE_SHA256}" | grep "$(sha256sum /usr/local/bin/docker-compose | cut -d ' ' -f 1)"
    fi

    echo "Done!"
fi
