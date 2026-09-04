#!/usr/bin/env bash

PHP_VERSION=${VERSION:-${1:-none}}
COMPOSER_VERSION=${COMPOSER:-${2:-none}}
XDEBUG_VERSION=${XDEBUG:-${3:-none}}

PHP_INI_DIR=${PHP_INI_DIR:-/usr/local/etc/php}
COMPOSER_SHA256=${COMPOSER_SHA256:-automatic}

PHP_CONFIGURE_EXTENSIONS=${PHP_CONFIGURE_EXTENSIONS:-${PHPCONFIGUREEXTENSIONS}}
PHP_ENABLE_EXTENSIONS=${PHP_ENABLE_EXTENSIONS:-${PHPENABLEEXTENSIONS}}
PHP_EXTRA_PACKAGES=${PHP_EXTRA_PACKAGES:-${EXTRAPACKAGES}}
PHP_INSTALL_EXTENSIONS=${PHP_INSTALL_EXTENSIONS:-${PHPINSTALLEXTENSIONS}}

set -e

export DEBIAN_FRONTEND=noninteractive
export PHP_INI_DIR=${PHP_INI_DIR}

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    libxslt-dev \
    autoconf \
    dpkg-dev \
    file \
    g++ \
    gcc \
    gnupg \
    libargon2-dev \
    libc-dev \
    libcurl4-openssl-dev \
    libedit-dev \
    libgd-dev \
    libonig-dev \
    libpng-dev \
    libsodium-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    libzip-dev \
    make \
    pkg-config \
    re2c \
    xz-utils \
    zlib1g-dev \
"

if [[ ${PHP_VERSION} != none ]]; then
    echo "Build PHP v${PHP_VERSION} from source ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES} ${PHP_EXTRA_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    curl -sSL -o /tmp/php.tar.xz https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz
    curl -sSL -o /tmp/php.tar.xz.asc https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz.asc

    export GNUPGHOME=$(mktemp -d)
    curl -sSL https://www.php.net/distributions/php-keyring.gpg | gpg --import
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
        --enable-bcmath \
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
    docker-php-ext-configure gd ${PHP_CONFIGURE_EXTENSIONS}
    docker-php-ext-install gd phar ${PHP_INSTALL_EXTENSIONS}
    docker-php-ext-enable opcache sodium ${PHP_ENABLE_EXTENSIONS}
    docker-php-source delete

    if [[ ${COMPOSER_VERSION} != none ]]; then
        curl -sSL -o /usr/local/bin/composer https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar
        chmod +x /usr/local/bin/composer

        if [[ ${COMPOSER_SHA256} = automatic ]]; then
            COMPOSER_SHA256=$(curl -sSL https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar.sha256sum)
        fi

        if [[ ${COMPOSER_SHA256} != skip ]]; then
            echo "${COMPOSER_SHA256}" | grep "$(sha256sum /usr/local/bin/composer | cut -d ' ' -f 1)"
        fi
    fi

    if [[ ${XDEBUG_VERSION} != none ]]; then
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

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
