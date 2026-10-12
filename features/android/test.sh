#!/usr/bin/env bash

set -e

source dev-container-features-test-lib

check "sdkmanager command" sdkmanager --version
check "adb command" adb version
check "Android SDK variables" bash -c '[[ ${ANDROID_HOME} == /opt/android && ${ANDROID_SDK_ROOT} == ${ANDROID_HOME} ]]'
check "Android build tools" bash -c 'test -x "$(find "${ANDROID_HOME}/build-tools" -name aapt2 | head -n 1)"'
check "Android platform" bash -c 'test -f "$(find "${ANDROID_HOME}/platforms" -name android.jar | head -n 1)"'
check "Android SDK writable" test -w "${ANDROID_HOME}"
if command -v emulator >/dev/null 2>&1; then
    check "emulator command" emulator -version
fi

TEST_DIR=$(mktemp -d)
trap 'rm -rf "${TEST_DIR}"' EXIT
BUILD_TOOLS=$(find "${ANDROID_HOME}/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)
ANDROID_JAR=$(find "${ANDROID_HOME}/platforms" -name android.jar | sort -V | tail -n 1)
mkdir -p "${TEST_DIR}/classes" "${TEST_DIR}/dex"
cat > "${TEST_DIR}/HelloActivity.java" <<'JAVA'
package dev.test;
public class HelloActivity extends android.app.Activity {
    @Override
    public void onCreate(android.os.Bundle state) {
        super.onCreate(state);
    }
}
JAVA
cat > "${TEST_DIR}/AndroidManifest.xml" <<'MANIFEST'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="dev.test">
    <uses-sdk android:minSdkVersion="24" />
    <application android:label="Toolchain Test">
        <activity android:name=".HelloActivity" android:exported="true" />
    </application>
</manifest>
MANIFEST
check "compile Android Java" javac -source 8 -target 8 -cp "${ANDROID_JAR}" -d "${TEST_DIR}/classes" "${TEST_DIR}/HelloActivity.java"
check "compile Android dex" "${BUILD_TOOLS}/d8" --lib "${ANDROID_JAR}" --output "${TEST_DIR}/dex" "${TEST_DIR}/classes/dev/test/HelloActivity.class"
check "link Android APK" "${BUILD_TOOLS}/aapt2" link -I "${ANDROID_JAR}" --manifest "${TEST_DIR}/AndroidManifest.xml" -o "${TEST_DIR}/app.apk"
check "package Android dex" jar --update --file "${TEST_DIR}/app.apk" -C "${TEST_DIR}/dex" classes.dex
check "create test signing key" keytool -genkeypair -keystore "${TEST_DIR}/test.keystore" -storepass android -keypass android -alias test -keyalg RSA -dname CN=Test -validity 1
check "sign Android APK" "${BUILD_TOOLS}/apksigner" sign --ks "${TEST_DIR}/test.keystore" --ks-pass pass:android "${TEST_DIR}/app.apk"
check "verify Android APK" "${BUILD_TOOLS}/apksigner" verify "${TEST_DIR}/app.apk"

reportResults
