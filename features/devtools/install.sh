#!/usr/bin/env bash

STEP_VERSION=${1:-none}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

PACKAGE_LIST=" \
    coreutils \
    cpio \
    cpustat \
    diffutils \
    dnsutils \
    ethtool \
    findutils \
    htop \
    ifstat \
    iftop \
    iperf \
    iproute2 \
    iptables \
    iptstate \
    iputils-arping \
    iputils-clockdiff \
    iputils-ping \
    iputils-tracepath \
    lsof \
    lynx \
    mtr \
    ncdu \
    net-tools \
    netcat-openbsd \
    nghttp2 \
    openssl \
    psmisc \
    rsync \
    socat \
    strace \
    sysstat \
    tcpdump \
    telnet \
    tree \
    unzip \
    wget \
"

echo "Install DevTools ..."

apt-get update
apt-get install --no-install-recommends --yes ${PACKAGE_LIST}
apt-get upgrade --no-install-recommends --yes

ARCHITECTURE=""
case "$(dpkg --print-architecture)" in
    i386) ARCHITECTURE=386;;
    amd64) ARCHITECTURE=amd64;;
    arm64) ARCHITECTURE=arm64;;
    armel) ARCHITECTURE=armv6;;
    armhf) ARCHITECTURE=armv7;;
    *) echo "unsupported architecture"; exit 1 ;;
esac

if [[ ${STEP_VERSION} != none ]]; then
    curl -sSL -o /tmp/step-cli.tar.gz https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/step_linux_${STEP_VERSION}_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/SHASUMS256.txt https://github.com/smallstep/cli/releases/download/v${STEP_VERSION}/checksums.txt

    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/step-cli.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/step-cli
    tar -xz -f /tmp/step-cli.tar.gz -C /tmp/step-cli --strip-components=1
    cp -v /tmp/step-cli/bin/step /usr/local/bin/step

    rm -rf /tmp/step-cli /tmp/SHASUMS256.txt /tmp/step-cli.tar.gz
fi

apt-get autoremove --yes
apt-get clean --yes
rm -rf /var/lib/apt/lists/*

echo "Done!"
