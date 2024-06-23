#!/usr/bin/env bash

PLATFORM_VERSION=${VERSION:-${1:-none}}
BUILD_TOOLS_VERSION=${BUILD:-${2:-none}}
EXTRA_COMPONENTS=${COMPONENTS:-$3}
COMMANDLINE_VERSION=${COMMANDLINE:-$4}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

ANDROID_COMPONENTS="build-tools;${BUILD_TOOLS_VERSION},cmdline-tools;latest,emulator,platform-tools,platforms;android-${PLATFORM_VERSION},${EXTRA_COMPONENTS}"
SDKMANAGER="/tmp/android/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android"

if [[ ${PLATFORM_VERSION} != none ]] && [[ ${BUILD_TOOLS_VERSION} != none ]]; then
    echo "Setup Android v${PLATFORM_VERSION} and build tools v${BUILD_TOOLS_VERSION} ..."

    curl -sSL -o /tmp/android.zip https://dl.google.com/android/repository/commandlinetools-linux-${COMMANDLINE_VERSION}_latest.zip

    mkdir -p /tmp/android /opt/android
    unzip -o /tmp/android.zip -d /tmp/android

    IFS=, read -r -a components <<< ${ANDROID_COMPONENTS}
    yes | ${SDKMANAGER[@]} --licenses
    ${SDKMANAGER[@]} --install ${components[@]}

    rm -rf /tmp/android /tmp/android.zip

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
