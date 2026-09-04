#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "node command" node --version
check "npm command" npm --version

reportResults
