#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "flutter command" flutter --version
check "dart command" dart --version

reportResults
