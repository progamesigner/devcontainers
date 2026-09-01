#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "herdr command" herdr --version

reportResults
