#!/usr/bin/env bash

JAVA_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${JAVA_VERSION} != none ]]; then
    echo "Setup Java v${JAVA_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        i386) ARCHITECTURE=x86;;
        amd64) ARCHITECTURE=x64;;
        aarch64|arm64) ARCHITECTURE=aarch64;;
        armel|armhf) ARCHITECTURE=arm;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/jdk.tar.gz https://api.adoptium.net/v3/binary/version/jdk-${JAVA_VERSION}/linux/${ARCHITECTURE}/jdk/hotspot/normal/eclipse

    mkdir -p /opt/java/temurin
    tar -xz -f /tmp/jdk.tar.gz -C /opt/java/temurin --strip-components=1

    find /opt/java/temurin/lib -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/temurin.conf
    ldconfig

    rm -rf /tmp/jdk.tar.gz

    echo "Done!"
fi
