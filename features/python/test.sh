#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "python3 command" python3 --version
check "pip3 command" pip3 --version

reportResults
