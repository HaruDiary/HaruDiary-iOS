#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-test}"
OUTPUT="${HARUDIARY_CI_OUTPUT:-${TMPDIR:-/tmp}/harudiary-ci}"
mkdir -p "$OUTPUT"
PROJECT="$ROOT/EveryDiary/EveryDiary.xcodeproj"

case "$MODE" in
  test)
    SIMULATOR_ID="${HARUDIARY_SIMULATOR_ID:-$(xcrun simctl list devices available -j | ruby -rjson -e '
      devices = JSON.parse(STDIN.read).fetch("devices").select { |runtime, _| runtime.include?("iOS") }.values.flatten
      phones = devices.select { |device| device["isAvailable"] && device["name"].start_with?("iPhone") }
      device = phones.find { |phone| phone["state"] == "Booted" } || phones.first
      abort "No available iPhone simulator. Install an iOS runtime in Xcode." unless device
      puts device.fetch("udid")
    ')}"
    RESULT="$OUTPUT/logic-tests-$(date +%Y%m%d%H%M%S)-$$.xcresult"
    xcodebuild -project "$PROJECT" -scheme EveryDiaryLogicTests \
      -configuration Debug -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -derivedDataPath "$OUTPUT/DerivedData" -resultBundlePath "$RESULT" \
      -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO \
      test CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$OUTPUT/tests.log"
    ;;
  build)
    # Compile an isolated copy: never overwrite a developer's Firebase configuration.
    WORKSPACE="$(mktemp -d "${TMPDIR:-/tmp}/harudiary-ci-build.XXXXXX")"
    trap 'rm -rf "$WORKSPACE"' EXIT
    rsync -a --exclude .git --exclude GoogleService-Info.plist --exclude DerivedData \
      --exclude .build --exclude .DS_Store "$ROOT/" "$WORKSPACE/"
    cat > "$WORKSPACE/EveryDiary/EveryDiary/GoogleService-Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>PROJECT_ID</key><string>harudiary-ci-not-a-real-project</string>
  <key>BUNDLE_ID</key><string>com.HexaDiary.EveryDiary</string>
  <key>GOOGLE_APP_ID</key><string>1:000000000000:ios:0000000000000000</string>
  <key>GCM_SENDER_ID</key><string>000000000000</string>
  <key>API_KEY</key><string>ci-placeholder-not-a-credential</string>
  <key>PLIST_VERSION</key><string>1</string>
  <key>IS_ANALYTICS_ENABLED</key><false/>
</dict></plist>
PLIST
    xcodebuild -project "$WORKSPACE/EveryDiary/EveryDiary.xcodeproj" -scheme EveryDiary \
      -configuration Debug -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$OUTPUT/AppDerivedData" -onlyUsePackageVersionsFromResolvedFile \
      build CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$OUTPUT/build.log"
    ;;
  *)
    echo "Usage: bash scripts/ci.sh [test|build]" >&2
    exit 2
    ;;
esac
