#!/bin/sh
# Xcode Cloud runs this after cloning. GoogleService-Info.plist is not in git, so it is written from
# the secret environment variable GOOGLE_SERVICE_INFO_PLIST_BASE64 set on the Xcode Cloud workflow.
# The value is never printed.
set -eu

TARGET="$CI_PRIMARY_REPOSITORY_PATH/EveryDiary/EveryDiary/GoogleService-Info.plist"

if [ -z "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]; then
  echo "error: GOOGLE_SERVICE_INFO_PLIST_BASE64 is not set on this Xcode Cloud workflow." >&2
  echo "Add it under Workflow > Environment > Environment Variables as a secret." >&2
  exit 1
fi

printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 -D > "$TARGET"

# Fail early on a broken value instead of shipping an app that cannot reach Firebase.
if ! plutil -lint "$TARGET" > /dev/null; then
  echo "error: GOOGLE_SERVICE_INFO_PLIST_BASE64 does not decode to a valid property list." >&2
  rm -f "$TARGET"
  exit 1
fi
if [ "$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "$TARGET")" != "com.HexaDiary.EveryDiary" ]; then
  echo "error: GoogleService-Info.plist is for a different bundle identifier." >&2
  rm -f "$TARGET"
  exit 1
fi

echo "GoogleService-Info.plist written for Xcode Cloud."

