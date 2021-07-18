#!/usr/bin/env bash

PYTHON_VERSION=${1:-"none"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES="\
    dpkg-dev \
    gcc \
    libbz2-dev \
    libc6-dev \
    libffi-dev \
    libgdbm-compat-dev \
    libgdbm-dev \
    liblzma-dev \
    libncurses-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    lzma-dev \
    make \
    tk-dev \
    uuid-dev \
    xz-utils \
    zlib1g-dev \
"

GPG_KEYS="\
    E3FF2839C048B25C084DEBE9B26995E310250568 \
"

if [ "${PYTHON_VERSION}" != "none" ]; then
    echo "Build Python v${PYTHON_VERSION} from source ..."

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    curl -sSL -o /tmp/python.tar.xz https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
    curl -sSL -o /tmp/python.tar.xz.asc https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz.asc

    export GNUPGHOME=$(mktemp -d)
    for GPG_KEY in ${GPG_KEYS}; do
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEY} || \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys ${GPG_KEY}
    done
    gpg --batch --verify /tmp/python.tar.xz.asc /tmp/python.tar.xz
    gpgconf --kill all
    rm -vrf ${GNUPGHOME}

    mkdir -p /usr/src/python
    tar -vxJ -f /tmp/python.tar.xz -C /usr/src/python --strip-components=1

    cd /usr/src/python
    export CFLAGS=""
    export CPPFLAGS=${CFLAGS}
    export LDFLAGS="-Wl,--strip-all"
    ./configure \
        --build=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE) \
        --enable-loadable-sqlite-extensions \
        --enable-optimizations \
        --enable-option-checking=fatal \
        --with-system-expat \
        --with-system-ffi \
        --without-ensurepip
    make -j $(nproc)
    make install
    cd -

    rm -vrf /tmp/python.tar.xz.asc /tmp/python.tar.xz /usr/src/python

    ln -vs /usr/local/bin/idle3 /usr/local/bin/idle
    ln -vs /usr/local/bin/pydoc3 /usr/local/bin/pydoc
    ln -vs /usr/local/bin/python3 /usr/local/bin/python
    ln -vs /usr/local/bin/python3-config /usr/local/bin/python-config
fi

echo "Done!"
