#!/usr/bin/env bash

CLAUDE_CODE_VERSION=${VERSION:-${1:-latest}}

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

if [[ ${CLAUDE_CODE_VERSION} = none ]]; then
    mkdir -p /usr/local/share
    printf '#!/bin/sh\nexit 0\n' > /usr/local/share/claude-code-init.sh
    chmod +x /usr/local/share/claude-code-init.sh
    exit 0
fi

echo "Setup Claude Code v${CLAUDE_CODE_VERSION} ..."

if [ -z "$(command -v node)" ] || [ -z "$(command -v npm)" ]; then
    echo "NodeJS or npm not found, please install Node.js before proceeding."
    exit 1
fi

npm install -g --prefix /usr/local/share/claude-code @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION#v}

CLAUDE_HOME="${_REMOTE_USER_HOME}"

cat << 'EOF' > /usr/local/share/claude-code-init.sh
#!/bin/sh

set -e

CLAUDE_HOME=@CLAUDE_HOME@

mkdir -p $CLAUDE_HOME/.claude
if [ ! -e $CLAUDE_HOME/.claude/.claude.json ]; then
    touch "$CLAUDE_HOME/.claude/.claude.json"
fi
ln -sf $CLAUDE_HOME/.claude/.claude.json $CLAUDE_HOME/.claude.json
EOF
sed -i \
    -e "s|@CLAUDE_HOME@|${CLAUDE_HOME}|g" \
    /usr/local/share/claude-code-init.sh
chmod +x /usr/local/share/claude-code-init.sh

echo "Done!"
