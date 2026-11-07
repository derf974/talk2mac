#!/bin/zsh
# Compile et assemble Talk2Mac.app (nécessaire pour les permissions micro/accessibilité).
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/Talk2Mac.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Talk2Mac "$APP/Contents/MacOS/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Talk2Mac</string>
<key>CFBundleDisplayName</key><string>Talk2Mac</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIdentifier</key><string>perso.talk2mac</string>
<key>CFBundleExecutable</key><string>Talk2Mac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Talk2Mac a besoin du micro pour la dictée.</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "OK -> $APP"
