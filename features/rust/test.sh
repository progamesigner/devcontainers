#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "rustc command" rustc --version
check "cargo command" cargo --version

reportResults
