#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "moshi-hook command" moshi-hook version
check "init script" test -x /usr/local/share/moshi-init.sh
check "devcontainer wrapper" test -x /usr/local/bin/moshi-devcontainer
check "init syntax" sh -n /usr/local/share/moshi-init.sh
check "wrapper syntax" sh -n /usr/local/bin/moshi-devcontainer

reportResults
