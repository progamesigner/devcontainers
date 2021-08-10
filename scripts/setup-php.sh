#!/usr/bin/env bash

PHP_VERSION=${1:-"none"}
COMPOSER_VERSION=${2:-"none"}
XDEBUG_VERSION=${3:-"none"}
PHP_INI_DIR=${4:-"/usr/local/etc/php"}
COMPOSER_SHA256=${5:-"automatic"}

set -e

export DEBIAN_FRONTEND=noninteractive
export PHP_INI_DIR=${PHP_INI_DIR}

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

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

if [ "${PHP_VERSION}" != "none" ]; then
    echo "Build PHP v${PHP_VERSION} from source ..."

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    curl -sSL -o /tmp/php.tar.xz https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz
    curl -sSL -o /tmp/php.tar.xz.asc https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz.asc

    export GNUPGHOME=$(mktemp -d)
    for GPG_KEY in ${GPG_KEYS}; do
        gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys ${GPG_KEY} || \
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys ${GPG_KEY}
    done
    gpg --batch --verify /tmp/php.tar.xz.asc /tmp/php.tar.xz
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    mkdir -p /usr/src/php
    tar -xJ -f /tmp/php.tar.xz -C /usr/src/php --strip-components=1

    cd /usr/src/php
    export CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
    export CPPFLAGS=${CFLAGS}
    export LDFLAGS="-Wl,-O1 -pie"
    ./configure \
        --build=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE) \
        --disable-phar \
        --enable-embed \
        --enable-ftp \
        --enable-mbstring \
        --enable-mysqlnd \
        --enable-option-checking=fatal \
        --enable-pcntl \
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
    cp -v php.ini-* ${PHP_INI_DIR}
    cp -v /tmp/php.tar.xz /usr/src/php.tar.xz
    cd -

    rm -rf /tmp/php.tar.xz.asc /tmp/php.tar.xz /usr/src/php

    curl -sSL -o /usr/local/bin/docker-php-source https://raw.githubusercontent.com/docker-library/php/master/docker-php-source
    curl -sSL -o /usr/local/bin/docker-php-ext-configure https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-configure
    curl -sSL -o /usr/local/bin/docker-php-ext-enable https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-enable
    curl -sSL -o /usr/local/bin/docker-php-ext-install https://raw.githubusercontent.com/docker-library/php/master/docker-php-ext-install
    chmod +x /usr/local/bin/docker-php-*

    echo "export PHP_INI_DIR=${PHP_INI_DIR}" >> /etc/bash.bashrc
    docker-php-source extract
    docker-php-ext-enable sodium
    docker-php-ext-install phar
    docker-php-source delete

    if [ "${COMPOSER_VERSION}" != "none" ]; then
        curl -sSL -o /usr/local/bin/composer https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar
        chmod +x /usr/local/bin/composer

        if [ "${COMPOSER_SHA256}" = "automatic" ]; then
            COMPOSER_SHA256=$(curl -sSL https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar.sha256sum)
        fi

        if [ "${COMPOSER_SHA256}" != "skip" ]; then
            echo "${COMPOSER_SHA256}" | grep "$(sha256sum /usr/local/bin/composer | cut -d ' ' -f 1)"
        fi
    fi

    if [ "${XDEBUG_VERSION}" != "none" ]; then
        docker-php-source extract
        mkdir -p /usr/src/php/ext/xdebug
        curl -sSL -o /tmp/php-xdebug.tar.gz https://xdebug.org/files/xdebug-${XDEBUG_VERSION}.tgz
        tar -xz -f /tmp/php-xdebug.tar.gz -C /usr/src/php/ext/xdebug --strip-components=1
        docker-php-ext-install xdebug
        docker-php-source delete

        rm -rf /tmp/php-xdebug.tar.gz

        echo "xdebug.mode = debug" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini
        echo "xdebug.start_with_request = yes" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini
        echo "xdebug.client_port = 9003" >> ${PHP_INI_DIR}/conf.d/docker-php-ext-xdebug.ini
    fi
fi

echo "Done!"
