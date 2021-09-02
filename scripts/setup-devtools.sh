#!/usr/bin/env bash

ENABLE_DEVTOOLS=${1:-"true"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

PACKAGE_LIST="\
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
    xxdiff \
"

if [ "${ENABLE_DEVTOOLS}" != "false" ]; then
    echo "Install DevTools ..."

    apt-get update
    apt-get install --no-install-recommends -y ${PACKAGE_LIST}
    apt-get upgrade --no-install-recommends -y

    echo "Done!"
fi
