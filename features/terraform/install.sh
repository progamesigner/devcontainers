#!/usr/bin/env bash

TERRAFORM_VERSION=${VERSION:-${1:-none}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    unzip \
"

if [[ ${TERRAFORM_VERSION} != none ]]; then
    echo "Setup Terraform v${TERRAFORM_VERSION} ..."

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    apt-get upgrade --no-install-recommends --yes

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        i386) ARCHITECTURE=386;;
        amd64) ARCHITECTURE=amd64;;
        arm64) ARCHITECTURE=arm64;;
        armel|armhf) ARCHITECTURE=arm;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac

    curl -sSL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCHITECTURE}.zip

    mkdir -p /usr/local/share/terraform
    unzip -o /tmp/terraform.zip -d /usr/local/share/terraform/bin

    rm -rf /tmp/terraform.zip

    echo "Done!"
fi
