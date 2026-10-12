#!/usr/bin/env bash

JAVA_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    ca-certificates \
    curl \
"

if [[ ${JAVA_VERSION} != none ]]; then
    echo "Setup Java v${JAVA_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        i386) ARCHITECTURE=x86;;
        amd64) ARCHITECTURE=x64;;
        aarch64|arm64) ARCHITECTURE=aarch64;;
        armel|armhf) ARCHITECTURE=arm;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${JAVA_VERSION} =~ ^[0-9]+$ ]]; then
        JAVA_URL=https://api.adoptium.net/v3/binary/latest/${JAVA_VERSION}/ga/linux/${ARCHITECTURE}/jdk/hotspot/normal/eclipse
    elif [[ ${JAVA_VERSION} =~ ^[0-9]+(\.[0-9]+)*\+[0-9]+$ ]]; then
        JAVA_URL=https://api.adoptium.net/v3/binary/version/jdk-${JAVA_VERSION/+/%2B}/linux/${ARCHITECTURE}/jdk/hotspot/normal/eclipse
    else
        echo "Use a JDK major (21) or an exact Temurin release (21.0.9+10)."
        exit 1
    fi

    JAVA_BINARY_URL=$(curl -fsS -o /dev/null -w '%{redirect_url}' ${JAVA_URL})
    curl -fsSL -o /tmp/jdk.tar.gz ${JAVA_BINARY_URL}
    curl -fsSL -o /tmp/jdk.tar.gz.sha256 ${JAVA_BINARY_URL}.sha256.txt
    echo "$(cut -d ' ' -f 1 /tmp/jdk.tar.gz.sha256)  /tmp/jdk.tar.gz" | sha256sum --check

    mkdir -p /opt/java/temurin
    tar -xz -f /tmp/jdk.tar.gz -C /opt/java/temurin --strip-components=1

    find /opt/java/temurin/lib -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/temurin.conf
    ldconfig

    rm -rf /tmp/jdk.tar.gz.sha256 /tmp/jdk.tar.gz

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
