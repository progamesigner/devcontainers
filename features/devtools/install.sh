#!/usr/bin/env bash

CLOUDFLARED_VERSION=${CLOUDFLARED:-none}
COSIGN_VERSION=${COSIGN:-latest}
TAILSCALE_VERSION=${TAILSCALE:-none}

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
    iotop \
    iperf \
    iproute2 \
    iptables \
    iptstate \
    iputils-arping \
    iputils-clockdiff \
    iputils-ping \
    iputils-tracepath \
    lsof \
    ltrace \
    lynx \
    moreutils \
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
"

echo "Install DevTools ..."

apt-get update
apt-get install --no-install-recommends --yes ${PACKAGE_LIST}
apt-get upgrade --no-install-recommends --yes

if [[ ${CLOUDFLARED_VERSION} != none ]]; then
    echo "Setup cloudflared v${CLOUDFLARED_VERSION} ..."

    curl -sSL -o /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

    cp -v /tmp/cloudflared /usr/local/bin/cloudflared

    chmod +x /usr/local/bin/cloudflared

    rm -rf /tmp/cloudflared
fi

if [[ ${COSIGN_VERSION} != none ]]; then
    echo "Setup cosign v${COSIGN_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        i386) ARCHITECTURE=386;;
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        armel) ARCHITECTURE=armv6;;
        armhf) ARCHITECTURE=armv7;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${COSIGN_VERSION} = latest ]]; then
        COSIGN_VERSION=$(curl -sSL https://api.github.com/repos/sigstore/cosign/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${COSIGN_VERSION} != v* ]]; then
        COSIGN_VERSION=v${COSIGN_VERSION}
    fi

    curl -sSL -o /tmp/cosign.deb https://github.com/sigstore/cosign/releases/latest/download/cosign_${COSIGN_VERSION#v}_${ARCHITECTURE}.deb
    dpkg --install /tmp/cosign.deb

    rm -rf /tmp/cosign.deb
fi

if [[ ${TAILSCALE_VERSION} != none ]]; then
    echo "Setup tailscale v${TAILSCALE_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        armhf) ARCHITECTURE=arm;;
        i386) ARCHITECTURE=386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/tailscale.tar.gz https://pkgs.tailscale.com/stable/tailscale_${TAILSCALE_VERSION}_${ARCHITECTURE}.tgz

    mkdir -p /tmp/tailscale
    tar -xz -f /tmp/tailscale.tar.gz -C /tmp/tailscale --strip-components=1
    cp -v /tmp/tailscale/tailscale /usr/local/bin/tailscale
    cp -v /tmp/tailscale/tailscaled /usr/local/bin/tailscaled

    mkdir -p /var/lib/tailscale
    mkdir -p /var/run/tailscale

    rm -rf /tmp/tailscale /tmp/tailscale.tar.gz
fi

echo "$(cat << 'EOF'
#!/bin/sh

set -e

execute() {
    if [ "$(id -u)" -ne 0 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

if [ -n "$(command -v cloudflared)" ] && [ -n "${CLOUDFLARE_TUNNEL_TOKEN}" ]; then
    if [ ! -f /etc/init.d/cloudflared ]; then
        execute cloudflared service install -- ${CLOUDFLARE_TUNNEL_TOKEN}
    fi

    execute service cloudflared restart
fi

if [ -n "$(command -v tailscaled)" ]; then
    execute tailscaled \
        --port=41641 \
        --socket=/var/run/tailscale/tailscaled.sock \
        --state=/var/lib/tailscale/tailscaled.state \
        --tun=userspace-networking
fi

if [ -n "$(command -v tailscale)" ] && [ -n "${TS_AUTHKEY}" ]; then
    execute tailscale up \
        --accept-dns=true \
        --accept-routes=true \
        --advertise-routes=${TS_ROUTES} \
        --authkey=${TS_AUTHKEY}
fi

if [ -f ${DEV_SETUP_PATH} ]; then
    execute apt-get update
    execute bash -c ${DEV_SETUP_PATH} -- ${DEV_SETUP_ARGS}
    execute apt-get autoremove --yes
    execute apt-get clean --yes
    execute rm -rf /var/lib/apt/lists/*
fi
EOF
)" > /usr/local/share/devtools-init.sh
chmod +x /usr/local/share/devtools-init.sh

apt-get autoremove --yes
apt-get clean --yes
rm -rf /var/lib/apt/lists/*

echo "Done!"
