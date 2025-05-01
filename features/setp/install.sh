#!/usr/bin/env bash

STEP_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${STEP_VERSION} != none ]]; then
    echo "Setup step v${STEP_VERSION} ..."

    curl -sSL -o /tmp/step-cli.tar.gz https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/step_linux_${STEP_VERSION}_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/step-cli.tar.gz.asc https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/checksums.txt

    cat /tmp/step-cli.tar.gz.asc | grep "$(sha256sum /tmp/step-cli.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/step-cli
    tar -xz -f /tmp/step-cli.tar.gz -C /tmp/step-cli --strip-components=1
    cp -v /tmp/step-cli/bin/step /usr/local/bin/step

    rm -rf /tmp/step-cli /tmp/step-cli.tar.gz.asc /tmp/step-cli.tar.gz
fi
