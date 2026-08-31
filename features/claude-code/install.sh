#!/usr/bin/env bash

set -e

export DEBIAN_FRONTEND=noninteractive

# Check the script is run as root
if [[ $(id -u) != 0 ]]; then
    echo "The script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script."
    exit 1
fi

echo "Setup Claude Code ..."

if [ -z "$(command -v node)" ] || [ -z "$(command -v npm)" ]; then
    echo "NodeJS or npm not found, please install Node.js before proceeding."
    exit 1
fi

npm install -g @anthropic-ai/claude-code

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
