#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

flutter create \
  --platforms=android \
  --org com.techezer \
  --project-name sankalp \
  "$TEMP_DIR/scaffold"

cp -R "$TEMP_DIR/scaffold/android" "$MOBILE_DIR/android"

MANIFEST="$MOBILE_DIR/android/app/src/main/AndroidManifest.xml"
sed -i '/<manifest/a\    <uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>' "$MANIFEST"
sed -i 's/android:label="sankalp"/android:label="Sankalp"/' "$MANIFEST"
sed -i '/<\/application>/i\        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n            <intent-filter>\n                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n            </intent-filter>\n        </receiver>' "$MANIFEST"

GRADLE="$MOBILE_DIR/android/app/build.gradle.kts"
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' "$GRADLE"
sed -i '/sourceCompatibility = JavaVersion.VERSION_17/a\        isCoreLibraryDesugaringEnabled = true' "$GRADLE"
if grep -q '^dependencies {' "$GRADLE"; then
  sed -i '/^dependencies {/a\    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")' "$GRADLE"
else
  printf '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")\n}\n' >> "$GRADLE"
fi

echo "Android project created for com.techezer.sankalp"
