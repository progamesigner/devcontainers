#!/usr/bin/env bash

PYTHON_VERSION=${VERSION:-${1:-none}}

PYTHON_OPTIMIZE=${OPTIMIZE:-false}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
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
    python3-dev \
    tk-dev \
    uuid-dev \
    xz-utils \
    zlib1g-dev \
"

GPG_KEYS=" \
    7169605F62C751356D054A26A821E680E5FA6305 \
    A035C8C19219BA821ECEA86B64E628F8D684696D \
    E3FF2839C048B25C084DEBE9B26995E310250568 \
    0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D \
    C9B104B3DD3AA72D7CCB1066FB9921286F5E1540 \
"

if [[ ${PYTHON_VERSION} != none ]]; then
    echo "Build Python v${PYTHON_VERSION} from source ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    curl -sSL -o /tmp/python.tar.xz https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
    curl -sSLf -o /tmp/python.tar.xz.asc https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz.asc || true
    curl -sSLf -o /tmp/python.tar.xz.sigstore https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz.sigstore || true

    if [ -n "$(command -v cosign)" ] && [ -f /tmp/python.tar.xz.sigstore ]; then
        cosign verify-blob --bundle=/tmp/python.tar.xz.sigstore --certificate-identity-regexp='.*' --certificate-oidc-issuer-regexp='.*' /tmp/python.tar.xz
    fi

    if [ -f /tmp/python.tar.xz.asc ]; then
        export GNUPGHOME=$(mktemp -d)
        gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys ${GPG_KEYS} || gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEYS} || true
        gpg --batch --verify /tmp/python.tar.xz.asc /tmp/python.tar.xz
        gpgconf --kill all
        rm -rf ${GNUPGHOME}
    fi

    mkdir -p /usr/src/python
    tar -xJ -f /tmp/python.tar.xz -C /usr/src/python --strip-components=1

    CONFIG_FLAGS=" \
        --build=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE) \
        --enable-loadable-sqlite-extensions \
        --enable-option-checking=fatal \
        --with-ensurepip=install \
        --with-system-expat \
    "
    if [[ ${PYTHON_OPTIMIZE} = true ]]; then
        CONFIG_FLAGS="${CONFIG_FLAGS} --enable-optimizations"
    fi

    cd /usr/src/python
    export CFLAGS=""
    export CPPFLAGS=${CFLAGS}
    export LDFLAGS="-Wl,--strip-all"
    ./configure --prefix=/usr/local ${CONFIG_FLAGS}
    make -j $(nproc)
    make install
    cd -

    rm -rf /tmp/python.tar.xz.asc /tmp/python.tar.xz.sigstore /tmp/python.tar.xz /usr/src/python

    ln -s /usr/local/bin/idle3 /usr/local/bin/idle
    ln -s /usr/local/bin/pip3 /usr/local/bin/pip
    ln -s /usr/local/bin/pydoc3 /usr/local/bin/pydoc
    ln -s /usr/local/bin/python3 /usr/local/bin/python
    ln -s /usr/local/bin/python3-config /usr/local/bin/python-config

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
