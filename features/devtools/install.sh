#!/usr/bin/env bash

ACT_VERSION=${ACT:-none}
BUF_VERSION=${BUF:-none}
CLOUDFLARED_VERSION=${CLOUDFLARED:-none}
STEP_VERSION=${STEP:-none}
TAILSCALE_VERSION=${TAILSCALE:-none}
WATCHMAN_VERSION=${WATCHMAN:-none}

BUF_SHA256=${BUF_SHA256:-automatic}

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

ARCHITECTURE=""
case "$(dpkg --print-architecture)" in
    i386) ARCHITECTURE=386;;
    amd64) ARCHITECTURE=amd64;;
    arm64) ARCHITECTURE=arm64;;
    armel) ARCHITECTURE=armv6;;
    armhf) ARCHITECTURE=armv7;;
    *) echo "unsupported architecture"; exit 1 ;;
esac

if [[ ${ACT_VERSION} != none ]]; then
    echo "Setup act v${ACT_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=arm64;;
        armhf) ARCHITECTURE=armv7;;
        i386) ARCHITECTURE=x386;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${ACT_VERSION} = latest ]]; then
        ACT_VERSION=$(curl -sSL https://api.github.com/repos/nektos/act/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${ACT_VERSION} != v* ]]; then
        ACT_VERSION=v${ACT_VERSION}
    fi

    curl -sSL -o /tmp/act.tar.gz https://github.com/nektos/act/releases/download/${ACT_VERSION}/act_Linux_${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/act.tar.gz.asc https://github.com/nektos/act/releases/download/${ACT_VERSION}/checksums.txt

    cat /tmp/act.tar.gz.asc | grep "$(sha256sum /tmp/act.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/act
    tar -xz -f /tmp/act.tar.gz -C /tmp/act
    cp -v /tmp/act/act /usr/local/bin/act

    rm -rf /tmp/act /tmp/act.tar.gz.asc /tmp/act.tar.xz
fi

if [[ ${BUF_VERSION} != none ]]; then
    echo "Setup buf v${BUF_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x86_64;;
        arm64) ARCHITECTURE=aarch64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${BUF_VERSION} = latest ]]; then
        BUF_VERSION=$(curl -sSL https://api.github.com/repos/bufbuild/buf/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${BUF_VERSION} != v* ]]; then
        BUF_VERSION=v${BUF_VERSION}
    fi

    curl -sSL -o /tmp/buf https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/buf-Linux-${ARCHITECTURE}
    curl -sSL -o /tmp/protoc-gen-buf-breaking https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/protoc-gen-buf-breaking-Linux-${ARCHITECTURE}
    curl -sSL -o /tmp/protoc-gen-buf-lint https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/protoc-gen-buf-lint-Linux-${ARCHITECTURE}
    curl -sSL -o /tmp/SHASUMS256.txt.asc https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/sha256.txt

    cat /tmp/SHASUMS256.txt.asc | grep "$(sha256sum /tmp/buf | cut -d ' ' -f 1)"
    cat /tmp/SHASUMS256.txt.asc | grep "$(sha256sum /tmp/protoc-gen-buf-breaking | cut -d ' ' -f 1)"
    cat /tmp/SHASUMS256.txt.asc | grep "$(sha256sum /tmp/protoc-gen-buf-lint | cut -d ' ' -f 1)"

    cp -v /tmp/buf /usr/local/bin/buf
    cp -v /tmp/protoc-gen-buf-breaking /usr/local/bin/protoc-gen-buf-breaking
    cp -v /tmp/protoc-gen-buf-lint /usr/local/bin/protoc-gen-buf-lint

    chmod +x /usr/local/bin/buf
    chmod +x /usr/local/bin/protoc-gen-buf-breaking
    chmod +x /usr/local/bin/protoc-gen-buf-lint

    rm -rf /tmp/buf /tmp/protoc-gen-buf-breaking /tmp/protoc-gen-buf-lint /tmp/SHASUMS256.txt
fi

if [[ ${CLOUDFLARED_VERSION} != none ]]; then
    echo "Setup cloudflared v${CLOUDFLARED_VERSION} ..."

    curl -sSL -o /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

    cp -v /tmp/cloudflared /usr/local/bin/cloudflared

    chmod +x /usr/local/bin/cloudflared

    rm -rf /tmp/cloudflared
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

if [[ ${WATCHMAN_VERSION} != none ]]; then
    echo "Setup watchman v${WATCHMAN_VERSION} ..."

    if [[ ${WATCHMAN_VERSION} = latest ]]; then
        WATCHMAN_VERSION=$(curl -sSL https://api.github.com/repos/facebook/watchman/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${WATCHMAN_VERSION} != v* ]]; then
        WATCHMAN_VERSION=v${WATCHMAN_VERSION}
    fi

    curl -sSL -o /tmp/watchman.deb https://github.com/facebook/watchman/releases/download/${WATCHMAN_VERSION}/watchman_ubuntu22.04_${WATCHMAN_VERSION}.deb

    apt-get install --fix-broken --yes /tmp/watchman.deb

    rm -rf /tmp/watchman.deb
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
