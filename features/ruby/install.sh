#!/usr/bin/env bash

RUBY_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    autoconf \
    gcc \
    libffi-dev \
    libgmp-dev \
    libreadline-dev \
    libssl-dev \
    libyaml-dev \
    zlib1g-dev \
"

if [[ ${RUBY_VERSION} != none ]]; then
    echo "Build Ruby v${RUBY_VERSION} from source ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    curl -sSL -o /tmp/ruby.tar.gz https://cache.ruby-lang.org/pub/ruby/$(echo ${RUBY_VERSION} | cut -d '.' -f 1,2)/ruby-${RUBY_VERSION}.tar.gz

    mkdir -p /usr/src/ruby
    tar -xz -f /tmp/ruby.tar.gz -C /usr/src/ruby --strip-components=1

    CONFIG_FLAGS=" \
        --build=$(dpkg-architecture --query DEB_BUILD_GNU_TYPE) \
    "

    cd /usr/src/ruby
    export CFLAGS=""
    export CPPFLAGS=${CFLAGS}
    export LDFLAGS="-Wl,--strip-all"
    ./configure --prefix=/usr/local ${CONFIG_FLAGS}
    make install -j $(nproc)
    cd -

    rm -rf /tmp/ruby.tar.gz /usr/src/ruby

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
