#!/usr/bin/env bash

# pip

PYPY_VERSION=${1:-"none"}
PYPY_PYTHON_VERSION=${2:-"none"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    bzip2 \
    gcc \
    pkg-config \
"

if [ "${PYPY_VERSION}" != "none" ] && [ "${PYPY_PYTHON_VERSION}" != "none" ]; then
    echo "Setup PyPy${PYPY_PYTHON_VERSION} v${PYPY_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=linux64;;
        arm64) ARCHITECTURE=aarch64;;
        i386) ARCHITECTURE=linux32;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/pypy.tar.bz2 https://downloads.python.org/pypy/pypy${PYPY_PYTHON_VERSION}-v${PYPY_VERSION}-${ARCHITECTURE}.tar.bz2

    mkdir -p /opt/pypy
    tar -xj -f /tmp/pypy.tar.bz2 -C /usr/local --strip-components=1

    pypy3 -m ensurepip --default-pip --upgrade

    rm -rf /tmp/tmp* /tmp/pypy.tar.bz2

    echo "Done!"
fi
