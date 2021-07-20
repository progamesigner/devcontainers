#!/usr/bin/env bash

RUST_VERSION=${1:-"none"}
CARGO_HOME=${2:-"/usr/local/cargo"}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES="\
    dpkg-dev \
    gcc \
    gzip \
    libc-dev \
    lldb \
"

if [ "${RUST_VERSION}" != "none" ]; then
    echo "Setup Rust v${RUST_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends -y ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends -y

    PLATFORM=""
    case "$(dpkg --print-architecture)" in
        amd64) PLATFORM=x86_64-unknown-linux-gnu;;
        arm64) PLATFORM=aarch64-unknown-linux-gnu;;
        armhf) PLATFORM=armv7-unknown-linux-gnueabihf;;
        i386) PLATFORM=i686-unknown-linux-gnu;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/rust.tar.gz https://static.rust-lang.org/dist/rust-${RUST_VERSION}-${PLATFORM}.tar.gz
    curl -sSL -o /tmp/rust.tar.gz.asc https://static.rust-lang.org/dist/rust-${RUST_VERSION}-${PLATFORM}.tar.gz.asc
    curl -sSL -o /tmp/rust-src.tar.gz https://static.rust-lang.org/dist/rustc-${RUST_VERSION}-src.tar.gz
    curl -sSL -o /tmp/rust-src.tar.gz.asc https://static.rust-lang.org/dist/rustc-${RUST_VERSION}-src.tar.gz.asc

    export GNUPGHOME=$(mktemp -d)
    curl -sSL https://static.rust-lang.org/rust-key.gpg.ascii | gpg --import
    gpg --batch --verify /tmp/rust.tar.gz.asc /tmp/rust.tar.gz
    gpg --batch --verify /tmp/rust-src.tar.gz.asc /tmp/rust-src.tar.gz
    gpgconf --kill all
    rm -rf ${GNUPGHOME}

    mkdir -p /tmp/rust
    tar -xz -f /tmp/rust.tar.gz -C /tmp/rust --strip-components=1

    RUST_COMPONENTS=$(cat /tmp/rust/components)
    for RUST_COMPONENT in ${RUST_COMPONENTS}; do
        for DIRECTIVE in $(cat /tmp/rust/${RUST_COMPONENT}/manifest.in); do
            if [[ "${DIRECTIVE}" = "file:"* ]]; then
                FILE=${DIRECTIVE#file:}
                mkdir -p /usr/local/$(dirname ${FILE})
                cp -v /tmp/rust/${RUST_COMPONENT}/${FILE} /usr/local/${FILE}
            elif [[ "${DIRECTIVE}" = "dir:"* ]]; then
                DIR=${DIRECTIVE#dir:}
                mkdir -p /usr/local/$(dirname ${DIR})
                cp -v -R /tmp/rust/${RUST_COMPONENT}/${DIR} /usr/local/${DIR}
            else
                echo "unsupported directive \"${DIRECTIVE}\"."; exit 1
            fi
        done
    done

    mkdir -p /usr/local/lib/rustlib/src/rust
    tar -xz -f /tmp/rust-src.tar.gz -C /usr/local/lib/rustlib/src/rust --strip-components=1

    rm -rf /tmp/rust /tmp/rust.tar.gz.asc /tmp/rust-src.tar.gz.asc /tmp/rust-src.tar.gz /tmp/rust.tar.gz

    mkdir -p ${CARGO_HOME}
    chmod a+rwx ${CARGO_HOME}

    echo "export CARGO_HOME=${CARGO_HOME}" >> /etc/bash.bashrc
    echo "export PATH=\${CARGO_HOME}/bin:\${PATH}" >> /etc/bash.bashrc
fi

echo "Done!"
