#!/usr/bin/env bash

GCLOUD_CLI_VERSION=${VERSION:-${1:-none}}
GCLOUD_ADDITIONAL_COMPONENTS=${COMPONENTS}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${GCLOUD_CLI_VERSION} != none ]]; then
    echo "Setup Google Cloud Cli v${GCLOUD_CLI_VERSION} ..."

    ARCHITECTURE=""
    case "$(dpkg --print-architecture)" in
        i386) ARCHITECTURE=x86;;
        amd64) ARCHITECTURE=x86_64;;
        arm64|armel|armhf) ARCHITECTURE=arm;;
        *) echo "unsupported architecture"; exit 1 ;;
    esac
    curl -sSL -o /tmp/gcloud-cli.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-${ARCHITECTURE}.tar.gz

    mkdir -p /usr/local/share/gcloud-cli
    tar -xz -f /tmp/gcloud-cli.tar.gz -C /usr/local/share/gcloud-cli --strip-components=1

    /usr/local/share/gcloud-cli/install.sh --command-completion=false --path-update=false --quiet --rc-path=false --usage-reporting=false
    /usr/local/share/gcloud-cli/bin/gcloud components install ${GCLOUD_ADDITIONAL_COMPONENTS} --quiet

    rm -rf /tmp/gcloud-cli.tar.gz

    echo "Done!"
fi
