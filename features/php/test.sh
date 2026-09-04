#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "php command" php --version

reportResults
