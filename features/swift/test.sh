#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "swift command" swift --version
check "swiftc command" swiftc --version
check "lldb command" lldb --version
check "sourcekit-lsp command" sourcekit-lsp --help

TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR}"' EXIT

echo 'import Foundation; print("Hello Swift")' > "${TEST_DIR}/hello.swift"
check "compile Swift" swiftc "${TEST_DIR}/hello.swift" -o "${TEST_DIR}/hello"
check "run Swift" bash -c '[[ $("$1/hello") == "Hello Swift" ]]' _ "${TEST_DIR}"
cd "${TEST_DIR}"
check "create Swift package" swift package init --type executable --name hello
check "build Swift package" swift build

reportResults
