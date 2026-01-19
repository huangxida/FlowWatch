#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/FlowWatch.xcodeproj"
SCHEME="FlowWatch"
CONFIGURATION="Release"

DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_PATH="$DIST_DIR/FlowWatch.xcarchive"
EXPORT_DIR="$DIST_DIR/export"
EXPORT_OPTIONS_PLIST="$DIST_DIR/ExportOptions.plist"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "未找到 xcodebuild。请安装 Xcode（建议 Xcode 15+）后重试。"
  exit 1
fi

DEVELOPER_DIR_PATH="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_DIR_PATH" == *"CommandLineTools"* ]]; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    echo "检测到已安装 Xcode，临时切换 DEVELOPER_DIR=$DEVELOPER_DIR"
  else
    echo "当前开发者目录指向 CommandLineTools：$DEVELOPER_DIR_PATH"
    echo "未检测到 /Applications/Xcode.app。请确认 Xcode 安装位置，或执行："
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
  fi
fi

mkdir -p "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"

TEAM_ID="${TEAM_ID:-}"

cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
EOF

if [[ -n "$TEAM_ID" ]]; then
  cat >> "$EXPORT_OPTIONS_PLIST" <<EOF
    <key>teamID</key>
    <string>$TEAM_ID</string>
EOF
fi

cat >> "$EXPORT_OPTIONS_PLIST" <<EOF
</dict>
</plist>
EOF

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

APP_PATH="$EXPORT_DIR/FlowWatch.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "未找到导出的 app：$APP_PATH"
  exit 1
fi

rm -rf "$DIST_DIR/FlowWatch.app"
cp -R "$APP_PATH" "$DIST_DIR/FlowWatch.app"

rm -f "$DIST_DIR/FlowWatch.zip"
ditto -c -k --sequesterRsrc --keepParent "$DIST_DIR/FlowWatch.app" "$DIST_DIR/FlowWatch.zip"

DMG_ROOT="$DIST_DIR/dmgroot"
rm -rf "$DMG_ROOT" "$DIST_DIR/FlowWatch.dmg"
mkdir -p "$DMG_ROOT"
cp -R "$DIST_DIR/FlowWatch.app" "$DMG_ROOT/FlowWatch.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "FlowWatch" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DIST_DIR/FlowWatch.dmg"

echo "产物已生成："
echo "- $DIST_DIR/FlowWatch.dmg"
echo "- $DIST_DIR/FlowWatch.zip"
