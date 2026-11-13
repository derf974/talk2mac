#!/bin/zsh
# Construit build/Talk2Mac.dmg : app autonome (whisper-cli + modèle embarqués) + raccourci Applications.
set -e
cd "$(dirname "$0")"
./build.sh --bundle
STAGE=$(mktemp -d)
cp -R build/Talk2Mac.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f build/Talk2Mac.dmg
hdiutil create -volname "Talk2Mac" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 build/Talk2Mac.dmg
rm -rf "$STAGE"
echo "OK -> build/Talk2Mac.dmg ($(du -h build/Talk2Mac.dmg | cut -f1))"
