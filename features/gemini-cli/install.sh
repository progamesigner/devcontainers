#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

echo "Setup Gemini CLI ..."

if [ -z "$(command -v node)" ] || [ -z "$(command -v npm)" ]; then
    echo "NodeJS or npm not found, please install Node.js before proceeding."
    exit 1
fi

npm install -g @google/gemini-cli

echo "Done!"
