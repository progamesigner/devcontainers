#!/usr/bin/env bash

DOCKER_VERSION=${1:-"none"}
DOCKER_SHA256=${2:-"automatic"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES="\
    dpkg-dev \
    gzip \
"

if [ "${DOCKER_VERSION}" != "none" ]; then
    echo "Setup Docker v${DOCKER_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=aarch64;;
        armel) ARCHITECTURE=armel;;
        armhf) ARCHITECTURE=armhf;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/docker.tar.gz https://download.docker.com/linux/static/stable/${ARCHITECTURE}/docker-${DOCKER_VERSION}.tgz

    tar -vxz -f /tmp/docker.tar.gz -C /usr/local/bin --strip-components=1

    if [ "${KUBECTL_SHA256}" = "automatic" ]; then
        # Docker doesn't provide any checksum files yet ...
        DOCKER_SHA256="skip"
    fi

    if [ "${DOCKER_SHA256}" != "skip" ]; then
        echo "${DOCKER_SHA256}" | grep "$(sha256sum /usr/local/bin/docker | cut -d ' ' -f 1)"
    fi

    rm -vrf /tmp/docker.tar.gz
fi

echo "Done!"
