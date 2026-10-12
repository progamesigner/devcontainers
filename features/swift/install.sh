#!/usr/bin/env bash

SWIFT_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    binutils \
    ca-certificates \
    curl \
    git \
    gnupg \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libncurses-dev \
    libpython3-dev \
    libsqlite3-0 \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    unzip \
    zlib1g-dev \
"

if [[ ${SWIFT_VERSION} != none ]]; then
    echo "Setup Swift v${SWIFT_VERSION} ..."

    . /etc/os-release
    case "${ID}-${VERSION_ID}" in
        ubuntu-22.04) UBUNTU_PACKAGES="libgcc-11-dev libstdc++-11-dev python3-lldb-13";;
        ubuntu-24.04) UBUNTU_PACKAGES="libgcc-13-dev libstdc++-13-dev";;
        ubuntu-26.04) UBUNTU_PACKAGES="binutils-gold libgcc-15-dev libstdc++-15-dev";;
        *) echo "Swift requires Ubuntu 22.04, 24.04, or 26.04."; exit 1 ;;
    esac

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE="";;
        arm64) ARCHITECTURE=-aarch64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES} ${UBUNTU_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    SWIFT_PLATFORM="ubuntu${VERSION_ID}${ARCHITECTURE}"
    SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu${VERSION_ID//./}${ARCHITECTURE}/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-${SWIFT_PLATFORM}.tar.gz"

    curl -fsSL -o /tmp/swift.tar.gz "${SWIFT_URL}"
    curl -fsSL -o /tmp/swift.tar.gz.sig "${SWIFT_URL}.sig"

    export GNUPGHOME=$(mktemp -d)
    curl -fsSL --compressed https://www.swift.org/keys/all-keys.asc | gpg --batch --import
    gpg --batch --verify /tmp/swift.tar.gz.sig /tmp/swift.tar.gz
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    rm -rf /opt/swift
    mkdir -p /opt/swift
    tar -xz -f /tmp/swift.tar.gz -C /opt/swift --strip-components=1

    rm -rf /tmp/swift.tar.gz.sig /tmp/swift.tar.gz

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
