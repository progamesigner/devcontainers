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

CLAUDE_USER="${_REMOTE_USER}"
CLAUDE_HOME="${_REMOTE_USER_HOME}"
CLAUDE_GROUP="$(id -gn "${CLAUDE_USER}")"

cat << 'EOF' > /usr/local/share/claude-code-init.sh
#!/bin/sh

set -e

CLAUDE_USER="@CLAUDE_USER@"
CLAUDE_HOME="@CLAUDE_HOME@"
CLAUDE_GROUP="@CLAUDE_GROUP@"

CLAUDE_CONFIG_BACKUP=$(find "${CLAUDE_HOME}/.claude/backups" -maxdepth 1 -type f -name '.*' -exec ls -1dt {} + 2>/dev/null | head -n 1)

if [ -n "${CLAUDE_CONFIG_BACKUP}" ] && [ -f "${CLAUDE_CONFIG_BACKUP}" ]; then
    cp "${CLAUDE_CONFIG_BACKUP}" "${CLAUDE_HOME}/.claude.json"
    chown "${CLAUDE_USER}:${CLAUDE_GROUP}" "${CLAUDE_HOME}/.claude.json" 2>/dev/null || true
fi

exec "$@"
EOF
sed -i \
    -e "s|@CLAUDE_USER@|${CLAUDE_USER}|g" \
    -e "s|@CLAUDE_HOME@|${CLAUDE_HOME}|g" \
    -e "s|@CLAUDE_GROUP@|${CLAUDE_GROUP}|g" \
    /usr/local/share/claude-code-init.sh
chmod +x /usr/local/share/claude-code-init.sh

echo "Done!"
