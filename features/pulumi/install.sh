#!/usr/bin/env bash

PULUMI_VERSION=${VERSION:-${1:-none}}
CRD2PULUMI_VERSION=${CRD2PULUMI:-${2:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${PULUMI_VERSION} != none ]]; then
    echo "Setup Pulumi v${PULUMI_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        amd64) ARCHITECTURE=x64;;
        arm64) ARCHITECTURE=arm64;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    if [[ ${PULUMI_VERSION} = latest ]]; then
        PULUMI_VERSION=$(curl -sSL https://api.github.com/repos/pulumi/pulumi/releases/latest | jq -r ".tag_name")
    fi

    if [[ ${PULUMI_VERSION} != v* ]]; then
        PULUMI_VERSION=v${PULUMI_VERSION}
    fi

    curl -sSL -o /tmp/pulumi.tar.gz https://get.pulumi.com/releases/sdk/pulumi-${PULUMI_VERSION}-linux-${ARCHITECTURE}.tar.gz
    curl -sSL -o /tmp/pulumi.tar.gz.asc https://get.pulumi.com/releases/sdk/pulumi-${PULUMI_VERSION#v}-checksums.txt

    cat /tmp/pulumi.tar.gz.asc | grep "$(sha256sum /tmp/pulumi.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/pulumi
    tar -xz -f /tmp/pulumi.tar.gz -C /tmp/pulumi --strip-components=1
    cp -v /tmp/pulumi/pulumi /usr/local/bin/pulumi
    cp -v /tmp/pulumi/pulumi-analyzer-policy /usr/local/bin/pulumi-analyzer-policy
    cp -v /tmp/pulumi/pulumi-analyzer-policy-python /usr/local/bin/pulumi-analyzer-policy-python
    cp -v /tmp/pulumi/pulumi-language-dotnet /usr/local/bin/pulumi-language-dotnet
    cp -v /tmp/pulumi/pulumi-language-go /usr/local/bin/pulumi-language-go
    cp -v /tmp/pulumi/pulumi-language-java /usr/local/bin/pulumi-language-java
    cp -v /tmp/pulumi/pulumi-language-nodejs /usr/local/bin/pulumi-language-nodejs
    cp -v /tmp/pulumi/pulumi-language-python /usr/local/bin/pulumi-language-python
    cp -v /tmp/pulumi/pulumi-language-python-exec /usr/local/bin/pulumi-language-python-exec
    cp -v /tmp/pulumi/pulumi-language-yaml /usr/local/bin/pulumi-language-yaml
    cp -v /tmp/pulumi/pulumi-resource-pulumi-nodejs /usr/local/bin/pulumi-resource-pulumi-nodejs
    cp -v /tmp/pulumi/pulumi-resource-pulumi-python /usr/local/bin/pulumi-resource-pulumi-python

    rm -rf /tmp/pulumi /tmp/pulumi.tar.gz.asc /tmp/pulumi.tar.xz

    echo "Done!"
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
    curl -sSL -o /tmp/crd2pulumi.tar.gz.asc https://github.com/pulumi/crd2pulumi/releases/download/${CRD2PULUMI_VERSION}/checksums.txt

    cat /tmp/crd2pulumi.tar.gz.asc | grep "$(sha256sum /tmp/crd2pulumi.tar.gz | cut -d ' ' -f 1)"

    mkdir -p /tmp/crd2pulumi
    tar -xz -f /tmp/crd2pulumi.tar.gz -C /tmp/crd2pulumi
    cp -v /tmp/crd2pulumi/crd2pulumi /usr/local/bin/crd2pulumi

    rm -rf /tmp/crd2pulumi /tmp/crd2pulumi.tar.gz.asc /tmp/crd2pulumi.tar.gz

    echo "Done!"
fi
