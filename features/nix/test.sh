#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "nix command" nix --version
check "devnix command" devnix status

reportResults
