#!/usr/bin/env bash

PHP_VERSION=${1:-"none"}
PHP_INI_DIR=${2:-"/usr/local/etc/php"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [ "${PHP_VERSION}" != "none" ]; then
    GPG_KEYS=""

    # PHP 8.1
    GPG_KEYS="\
        528995BFEDFBA7191D46839EF9BA0ADA31CBD89E \
        39B641343D8C104B2B146DC3F9C39DC0B9698544 \
        F1F692238FBC1666E5A5CCD4199F9DFEF6FFBAFD \
        ${GPG_KEYS}
    "

    # PHP 8.0
    GPG_KEYS="\
        1729F83938DA44E27BA0F4D3DBDB397470D12172 \
        BFDDD28642824F8118EF77909B67A5C12229118F \
        ${GPG_KEYS}
    "

    # PHP 7.4
    GPG_KEYS="\
        5A52880781F755608BF815FC910DEB46F53EA312 \
        42670A7FE4D0441C8E4632349E4FDC074A4EF02D \
        ${GPG_KEYS}
    "

    # PHP 7.3
    GPG_KEYS="\
        CBAF69F173A0FEA4B537F470D66C9593118BCCB6 \
        F38252826ACD957EF380D39F2F7956BC5DA04B5D \
        ${GPG_KEYS}
    "

    echo "Building PHP ${PHP_VERSION} from source ..."

    BUILD_PACKAGES="\
        autoconf \
        dpkg-dev \
        file \
        g++ \
        gcc \
        libargon2-dev \
        libc-dev \
        libcurl4-openssl-dev \
        libedit-dev \
        libonig-dev \
        libsodium-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        make \
        pkg-config \
        re2c \
        xz-utils \
        zlib1g-dev \
    "

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    curl -sSL -o /tmp/php.tar.xz https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz
    curl -sSL -o /tmp/php.tar.xz.asc https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz.asc

    GNUPGHOME=$(mktemp -d)
    for GPG_KEY in ${GPG_KEYS}; do
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEY} || \
        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys ${GPG_KEY}
    done
    gpg --batch --verify /tmp/php.tar.xz.asc /tmp/php.tar.xz
    gpgconf --kill all
    rm -vrf ${GNUPGHOME}

    mkdir -p /usr/src/php
    tar -vxJf /tmp/php.tar.xz -C /usr/src/php --strip-components=1

    cd /usr/src/php
    export CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
    export CPPFLAGS=${CFLAGS}
    export LDFLAGS="-Wl,-O1 -pie"
    ./configure \
        --build=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE) \
        --enable-embed \
        --enable-ftp \
        --enable-mbstring \
        --enable-mysqlnd \
        --enable-option-checking=fatal \
        --with-config-file-path=${PHP_INI_DIR} \
        --with-config-file-scan-dir=${PHP_INI_DIR}/conf.d \
        --with-curl \
        --with-libdir=lib/$(dpkg-architecture --query DEB_BUILD_MULTIARCH) \
        --with-libedit \
        --with-mhash \
        --with-openssl \
        --with-password-argon2 \
        --with-pdo-sqlite=/usr \
        --with-pic \
        --with-sodium=shared \
        --with-sqlite3=/usr \
        --with-zlib

    make -j $(nproc)
    make install

    mkdir -vp ${PHP_INI_DIR}/conf.d
    cp -v /tmp/php.tar.xz /usr/src/php.tar.xz
    cp -v php.ini-* ${PHP_INI_DIR}
    curl -sSL -o /usr/local/bin/docker-php-source https://raw.githubusercontent.com/docker-library/php/master/docker-php-source
    curl -sSL -o /usr/local/bin/docker-php-ext-configure https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-configure
    curl -sSL -o /usr/local/bin/docker-php-ext-enable https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-enable
    curl -sSL -o /usr/local/bin/docker-php-ext-install https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-install
    chmod -v +x /usr/local/bin/docker-php-*

    cd -
    rm -vrf /tmp/php.tar.xz.asc /tmp/php.tar.xz /usr/src/php

    echo "export PHP_INI_DIR=${PHP_INI_DIR}" >> /etc/bash.bashrc
    docker-php-ext-enable sodium
fi

echo "Done!"
