#!/usr/bin/env bash

CRD2PULUMI_VERSION=${1:-none}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${CRD2PULUMI_VERSION} != none ]]; then
    echo "Setup CRD2Pulumi v${CRD2PULUMI_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${CRD2PULUMI_VERSION} = latest ]]; then
        CRD2PULUMI_VERSION=$(curl -sSL https://api.github.com/repos/pulumi/crd2pulumi/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${CRD2PULUMI_VERSION} != v* ]]; then
        CRD2PULUMI_VERSION=v${CRD2PULUMI_VERSION}
    fi

    curl -sSL -o /tmp/crd2pulumi.tar.gz https://github.com/pulumi/crd2pulumi/releases/download/${CRD2PULUMI_VERSION}/crd2pulumi-${CRD2PULUMI_VERSION}-linux-${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/SHASUMS256.txt https://github.com/pulumi/crd2pulumi/releases/download/${CRD2PULUMI_VERSION}/checksums.txt

    cat /tmp/SHASUMS256.txt | grep "$(sha256sum /tmp/crd2pulumi.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/crd2pulumi
    tar -xz -f /tmp/crd2pulumi.tar.gz -C /tmp/crd2pulumi
    cp -v /tmp/crd2pulumi/crd2pulumi /usr/local/bin/crd2pulumi

    rm -rf /tmp/crd2pulumi /tmp/SHASUMS256.txt /tmp/crd2pulumi.tar.gz

    echo "Done!"
fi
