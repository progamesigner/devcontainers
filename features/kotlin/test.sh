#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "kotlin command" kotlin -version
check "kotlinc command" kotlinc -version

TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR}"' EXIT

echo 'fun main() = println("Hello Kotlin")' > "${TEST_DIR}/hello.kt"
check "compile Kotlin" kotlinc "${TEST_DIR}/hello.kt" -include-runtime -d "${TEST_DIR}/hello.jar"
check "run Kotlin" bash -c '[[ $(java -jar "$1/hello.jar") == "Hello Kotlin" ]]' _ "${TEST_DIR}"

reportResults
