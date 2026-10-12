#!/usr/bin/env bash

PLATFORM_VERSION=${VERSION:-${1:-none}}
BUILD_TOOLS_VERSION=${BUILD:-${2:-none}}
EXTRA_COMPONENTS=${COMPONENTS:-${3:-}}
COMMANDLINE_VERSION=${COMMANDLINE:-${4:-15859902}}
ANDROID_EMULATOR=${EMULATOR:-${5:-true}}

USERNAME=${_REMOTE_USER:-${USERNAME:-vscode}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

BUILD_PACKAGES=" \
    ca-certificates \
    curl \
    unzip \
"

EMULATOR_PACKAGES=" \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libglu1-mesa \
    libice6 \
    libnss3 \
    libpng-dev \
    libpulse0 \
    libsm6 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libxkbfile1 \
    libxrandr2 \
    libxtst6 \
"

if [[ ${PLATFORM_VERSION} != none ]] || [[ ${BUILD_TOOLS_VERSION} != none ]]; then
    echo "Setup Android v${PLATFORM_VERSION} and build tools v${BUILD_TOOLS_VERSION} ..."

    if [[ ${PLATFORM_VERSION} = none ]] || [[ ${BUILD_TOOLS_VERSION} = none ]]; then
        echo "Set both the Android Platform version and Build Tools version, or set both to none."
        exit 1
    fi

    if [[ $(dpkg --print-architecture) != amd64 ]]; then
        echo "Android SDK for Linux is only published for amd64, but this is $(dpkg --print-architecture)."
        exit 1
    fi

    ANDROID_COMPONENTS=("platform-tools" "platforms;android-${PLATFORM_VERSION}" "build-tools;${BUILD_TOOLS_VERSION}")
    if [[ ${ANDROID_EMULATOR} = true ]]; then
        ANDROID_COMPONENTS+=("emulator")
    fi

    IFS=, read -r -a EXTRA_COMPONENT_LIST <<< "${EXTRA_COMPONENTS}"
    for EXTRA_COMPONENT in "${EXTRA_COMPONENT_LIST[@]}"; do
        if [[ -n ${EXTRA_COMPONENT} ]]; then
            ANDROID_COMPONENTS+=("${EXTRA_COMPONENT}")
        fi
        if [[ ${EXTRA_COMPONENT} = emulator ]]; then
            ANDROID_EMULATOR=true
        fi
    done

    apt-get update
    apt-get install --no-install-recommends --yes ${BUILD_PACKAGES}
    if [[ ${ANDROID_EMULATOR} = true ]]; then
        apt-get install --no-install-recommends --yes ${EMULATOR_PACKAGES}
    fi
    apt-get upgrade --no-install-recommends --yes

    curl -fsSL -o /tmp/android.zip https://dl.google.com/android/repository/commandlinetools-linux-${COMMANDLINE_VERSION}_latest.zip
    curl -fsSL -o /tmp/android-repository.xml https://dl.google.com/android/repository/repository2-3.xml

    grep -B 1 "<url>commandlinetools-linux-${COMMANDLINE_VERSION}_latest.zip</url>" /tmp/android-repository.xml | grep "$(sha1sum /tmp/android.zip | cut -d ' ' -f 1)"

    mkdir -p /tmp/android /opt/android/cmdline-tools
    unzip -q -o /tmp/android.zip -d /tmp/android
    rm -rf /opt/android/cmdline-tools/latest
    mv /tmp/android/cmdline-tools /opt/android/cmdline-tools/latest

    SDKMANAGER="/opt/android/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android"
    yes | ${SDKMANAGER} --licenses
    ${SDKMANAGER} --install "${ANDROID_COMPONENTS[@]}"

    if id ${USERNAME} > /dev/null 2>&1; then
        chown -R ${USERNAME}:${USERNAME} /opt/android
    fi

    rm -rf /tmp/android /tmp/android-repository.xml /tmp/android.zip

    apt-get autoremove --yes
    apt-get clean --yes
    rm -rf /var/lib/apt/lists/*

    echo "Done!"
fi
