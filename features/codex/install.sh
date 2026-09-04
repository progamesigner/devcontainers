#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    bubblewrap \
"

echo "Setup Codex ..."

if [ -z "$(command -v node)" ] || [ -z "$(command -v npm)" ]; then
    echo "NodeJS or npm not found, please install Node.js before proceeding."
    exit 1
fi

apt-get update
apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
apt-get upgrade --no-install-recommends --yes

npm install -g --prefix /usr/local/share/codex @openai/codex

apt-get autoremove --yes
apt-get clean --yes
rm -rf /var/lib/apt/lists/*

echo "Done!"
