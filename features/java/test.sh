#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "java command" java -version
check "javac command" javac -version

TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR}"' EXIT

cat > "${TEST_DIR}/Hello.java" <<'JAVA'
public class Hello {
    public static void main(String[] args) {
        System.out.println("Hello Java");
    }
}
JAVA
check "compile Java" javac -d "${TEST_DIR}" "${TEST_DIR}/Hello.java"
check "run Java" bash -c '[[ $(java -cp "$1" Hello) == "Hello Java" ]]' _ "${TEST_DIR}"

reportResults
