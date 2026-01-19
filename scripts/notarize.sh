#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "用法：scripts/notarize.sh <dmg-or-zip-path>"
  exit 2
fi

FILE_PATH="$1"
if [[ ! -f "$FILE_PATH" ]]; then
  echo "文件不存在：$FILE_PATH"
  exit 2
fi

APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"

NOTARYTOOL_KEY_ID="${NOTARYTOOL_KEY_ID:-}"
NOTARYTOOL_ISSUER_ID="${NOTARYTOOL_ISSUER_ID:-}"
NOTARYTOOL_KEY_FILE="${NOTARYTOOL_KEY_FILE:-}"

if [[ -n "$NOTARYTOOL_KEY_ID" && -n "$NOTARYTOOL_ISSUER_ID" && -n "$NOTARYTOOL_KEY_FILE" ]]; then
  xcrun notarytool submit "$FILE_PATH" --wait --key "$NOTARYTOOL_KEY_FILE" --key-id "$NOTARYTOOL_KEY_ID" --issuer "$NOTARYTOOL_ISSUER_ID"
elif [[ -n "$APPLE_ID" && -n "$APPLE_TEAM_ID" && -n "$APPLE_APP_PASSWORD" ]]; then
  xcrun notarytool submit "$FILE_PATH" --wait --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD"
else
  echo "缺少公证凭据。请提供以下两种方式之一的环境变量："
  echo "- App Store Connect API Key：NOTARYTOOL_KEY_ID, NOTARYTOOL_ISSUER_ID, NOTARYTOOL_KEY_FILE"
  echo "- Apple ID：APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD"
  exit 2
fi

xcrun stapler staple "$FILE_PATH"
xcrun stapler validate "$FILE_PATH"

echo "公证并 stapling 完成：$FILE_PATH"
