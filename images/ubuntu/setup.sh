#!/usr/bin/env bash

USERNAME=${USERNAME:-${1:-vscode}}
USER_UID=${USER_UID:-${2:-1000}}
USER_GID=${USER_GID:-${3:-1000}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

# Allow use root as user
if [[ ${USERNAME} = root || ${USERNAME} = none ]]; then
    USERNAME=root
    USER_UID=0
    USER_GID=0
fi

# Install packages
PACKAGE_LIST=" \
    apt-transport-https \
    apt-utils \
    bash \
    ca-certificates \
    curl \
    dialog \
    gettext-base \
    git \
    git-lfs \
    gnupg2 \
    init-system-helpers \
    jq \
    less \
    libc6 \
    libgcc1 \
    libgssapi-krb5-2 \
    libicu[0-9][0-9] \
    libkrb5-3 \
    libstdc++6 \
    locales \
    lsb-release \
    make \
    man-db \
    manpages \
    manpages-dev \
    openssh-client \
    procps \
    ripgrep \
    sudo \
    tar \
    tzdata \
    unzip \
    vim-tiny \
    wget \
    wireguard \
    zsh \
"

if [ -n "$(apt-cache --names-only search ^libssl3$)" ]; then
    PACKAGE_LIST="${PACKAGE_LIST} libssl3"
elif [ -n "$(apt-cache --names-only search ^libssl1.1$)" ]; then
    PACKAGE_LIST="${PACKAGE_LIST} libssl1.1"
fi

echo "Packages to verify are installed: ${PACKAGE_LIST}"
apt-get update
apt-get install --no-install-recommends --yes ${PACKAGE_LIST}
apt-get upgrade --no-install-recommends --yes

# Ensure at least the en_US.UTF-8 UTF-8 locale is available
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Create non-root user with matched UID/GID
if [[ ${USERNAME} != root ]]; then
    if [ -z "$(getent group ${USER_GID})" ]; then
        groupadd -g ${USER_GID} ${USERNAME}
    fi

    if [ -z "$(getent passwd ${USER_UID})" ]; then
        useradd -g ${USER_GID} -ms /bin/bash -u ${USER_UID} ${USERNAME}
    fi

    if [[ "$(id -ng ${USER_GID})" != "${USERNAME}" ]]; then
        groupmod -n ${USERNAME} $(id -ng ${USER_GID})
    fi

    if [[ "$(id -nu ${USER_UID})" != "${USERNAME}" ]]; then
        usermod -d /home/${USERNAME} -g ${USER_GID} -l ${USERNAME} -ms /bin/bash $(id -nu ${USER_UID})
    fi

    # Add non-root user to sudoers
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}
    chmod ug=rw,o= /etc/sudoers.d/${USERNAME}
fi

# Add shim: code - it fallbacks to code-insiders if code is not available
echo "$(cat << 'EOF'
#!/bin/sh

get_in_path_except_current() {
    which -a "$1" | grep -A1 "$0" | grep -v "$0"
}

code="$(get_in_path_except_current code)"

if [ -n "$code" ]; then
    exec "$code" "$@"
elif [ -n "$(command -v code-insiders)" ]; then
    exec code-insiders "$@"
else
    echo "code or code-insiders is not installed" >&2
    exit 127
fi
EOF
)" > /usr/local/bin/code
chmod +x /usr/local/bin/code

# Add shim: systemctl - tells people to use 'service' if systemd is not running
echo "$(cat << 'EOF'
#!/bin/sh

set -e

if [ -d /run/systemd/system ]; then
    exec /bin/systemctl/systemctl "$@"
else
    echo '\n"systemd" is not running in this container due to its overhead.\nUse the "service" command to start services intead. e.g.: \n\nservice --status-all'
fi
EOF
)" > /usr/local/bin/systemctl
chmod +x /usr/local/bin/systemctl

# Configure shell
SHELL_RC_SNIPPET="$(cat << 'EOF'
if [ -z "${USER}" ]; then export USER=$(whoami); fi
if [[ "${PATH}" != *"$HOME/.local/bin"* ]]; then export PATH="${PATH}:$HOME/.local/bin"; fi

# Display optional first run image specific notice if configured and terminal is interactive
if [ -t 1 ] && [[ "${TERM_PROGRAM}" = "vscode" || "${TERM_PROGRAM}" = "codespaces" ]] && [ ! -f "$HOME/.config/vscode-dev-containers/first-run-notice-already-displayed" ]; then
    if [ -f "/usr/local/etc/vscode-dev-containers/first-run-notice.txt" ]; then
        cat "/usr/local/etc/vscode-dev-containers/first-run-notice.txt"
    elif [ -f "/workspaces/.codespaces/shared/first-run-notice.txt" ]; then
        cat "/workspaces/.codespaces/shared/first-run-notice.txt"
    fi
    mkdir -p "$HOME/.config/vscode-dev-containers"
    # Mark first run notice as displayed after 10s to avoid problems with fast terminal refreshes hiding it
    ((sleep 10s; touch "$HOME/.config/vscode-dev-containers/first-run-notice-already-displayed") &)
fi

# Set the default git editor if not already set
if [ -z "$(git config --get core.editor)" ] && [ -z "${GIT_EDITOR}" ]; then
    if  [ "${TERM_PROGRAM}" = "vscode" ]; then
        if [ -n "$(command -v code-insiders)" ] && [ -z "$(command -v code)" ]; then
            export GIT_EDITOR="code-insiders --wait"
        else
            export GIT_EDITOR="code --wait"
        fi
    fi
fi
EOF
)"

USER_RC_SNIPPET="$(cat <<'EOF'
# Codespaces bash prompt theme
__bash_prompt() {
    local userpart='`export XIT=$? \
        && [ ! -z "${GITHUB_USER}" ] && echo -n "\[\033[0;32m\]@${GITHUB_USER} " || echo -n "\[\033[0;32m\]\u " \
        && [ "$XIT" -ne "0" ] && echo -n "\[\033[1;31m\]➜" || echo -n "\[\033[0m\]➜"`'
    local gitbranch='`\
        if [ "$(git config --get devcontainers-theme.hide-status 2>/dev/null)" != 1 ] && [ "$(git config --get codespaces-theme.hide-status 2>/dev/null)" != 1 ]; then \
            export BRANCH=$(git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git --no-optional-locks rev-parse --short HEAD 2>/dev/null); \
            if [ "${BRANCH}" != "" ]; then \
                echo -n "\[\033[0;36m\](\[\033[1;31m\]${BRANCH}" \
                && if [ "$(git config --get devcontainers-theme.show-dirty 2>/dev/null)" = 1 ] && \
                    git --no-optional-locks ls-files --error-unmatch -m --directory --no-empty-directory -o --exclude-standard ":/*" > /dev/null 2>&1; then \
                        echo -n " \[\033[1;33m\]✗"; \
                fi \
                && echo -n "\[\033[0;36m\]) "; \
            fi; \
        fi`'
    local lightblue='\[\033[1;34m\]'
    local removecolor='\[\033[0m\]'
    PS1="${userpart} ${lightblue}\w ${gitbranch}${removecolor}\$ "
    unset -f __bash_prompt
}
__bash_prompt
export PROMPT_DIRTRIM=4
EOF
)"

if [[ ${USERNAME} = root ]]; then
    USER_RC_PATH=/root
else
    USER_RC_PATH=/home/${USERNAME}
fi

if [[ ! -f ${USER_RC_PATH}/.bashrc || ! -s ${USER_RC_PATH}/.bashrc ]]; then
    cp -v /etc/skel/.bashrc ${USER_RC_PATH}/.bashrc
fi

if [[ ! -f ${USER_RC_PATH}/.profile || ! -s ${USER_RC_PATH}/.profile ]]; then
    cp -v /etc/skel/.profile ${USER_RC_PATH}/.profile
fi

echo "${SHELL_RC_SNIPPET}" >> /etc/bash.bashrc
echo "${SHELL_RC_SNIPPET}" >> /etc/zsh/zshrc
echo "${USER_RC_SNIPPET}" >> ${USER_RC_PATH}/.bashrc
echo 'export PROMPT_DIRTRIM=4' >> ${USER_RC_PATH}/.bashrc
if [[ ${USERNAME} != root ]]; then
    echo "${USER_RC_SNIPPET}" >> /root/.bashrc
    echo 'export PROMPT_DIRTRIM=4' >> /root/.bashrc
fi
chown -v ${USERNAME}:${USERNAME} ${USER_RC_PATH}/.bashrc

# Create folders
mkdir -p ${USER_RC_PATH}/.cache
mkdir -p ${USER_RC_PATH}/.config

chown -v ${USERNAME}:${USERNAME} ${USER_RC_PATH}/.cache
chown -v ${USERNAME}:${USERNAME} ${USER_RC_PATH}/.config

# Clean up
apt-get autoremove --yes
apt-get clean --yes
rm -rf /var/lib/apt/lists/*

echo "Done!"
