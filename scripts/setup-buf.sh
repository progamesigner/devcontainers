#!/usr/bin/env bash

BUF_VERSION=${1:-none}
BUF_SHA256=${2:-automatic}

set -e

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
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
    curl -sSL -o /tmp/SHASUMS256.txt https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/sha256.txt

    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/buf | cut -d ' ' -f 1)"
    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/protoc-gen-buf-breaking | cut -d ' ' -f 1)"
    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/protoc-gen-buf-lint | cut -d ' ' -f 1)"

    cp -v /tmp/buf /usr/local/bin/buf
    cp -v /tmp/protoc-gen-buf-breaking /usr/local/bin/protoc-gen-buf-breaking
    cp -v /tmp/protoc-gen-buf-lint /usr/local/bin/protoc-gen-buf-lint

    chmod +x /usr/local/bin/buf
    chmod +x /usr/local/bin/protoc-gen-buf-breaking
    chmod +x /usr/local/bin/protoc-gen-buf-lint

    rm -rf /tmp/buf /tmp/protoc-gen-buf-breaking /tmp/protoc-gen-buf-lint /tmp/SHASUMS256.txt

    echo "Done!"
fi
