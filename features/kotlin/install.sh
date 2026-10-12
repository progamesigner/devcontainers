#!/usr/bin/env bash

KOTLIN_VERSION=${VERSION:-${1:-none}}
KOTLIN_VERSION=${KOTLIN_VERSION#v}

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
    unzip \
"

if [[ ${KOTLIN_VERSION} != none ]]; then
    echo "Setup Kotlin v${KOTLIN_VERSION} ..."

    if ! command -v java >/dev/null 2>&1; then
        echo "Kotlin requires a JDK. Enable the Java feature before Kotlin."
        exit 1
    fi

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    curl -fsSL -o /tmp/kotlin.zip "https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip"
    curl -fsSL -o /tmp/kotlin.zip.sha256 "https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip.sha256"
    echo "$(cat /tmp/kotlin.zip.sha256)  /tmp/kotlin.zip" | sha256sum --check

    unzip -q /tmp/kotlin.zip -d /opt
    mv /opt/kotlinc /opt/kotlin

    rm -rf /tmp/kotlin.zip /tmp/kotlin.zip.sha256

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
