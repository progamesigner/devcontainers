#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "moshi-hook command" moshi-hook version
check "init script" test -x /usr/local/share/moshi-init.sh

reportResults
