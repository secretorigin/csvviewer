#!/bin/bash
# Собирает релизную версию и упаковывает её в SQLoverCSV.app,
# который можно запускать двойным кликом и держать в /Applications.
set -euo pipefail

APP_NAME="SQL over CSV"
BINARY_NAME="SQLoverCSV"
BUNDLE_ID="com.sqlovercsv.app"

cd "$(dirname "$0")"

echo "==> Собираю релиз (компиляция DuckDB может занять пару минут)…"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"
APP_DIR="$BIN_PATH/$APP_NAME.app"

echo "==> Собираю бандл: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH/$BINARY_NAME" "$APP_DIR/Contents/MacOS/$BINARY_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$BINARY_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>CSV File</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.comma-separated-values-text</string>
                <string>public.plain-text</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "==> Готово: $APP_DIR"
echo "    Открыть: open \"$APP_DIR\""
