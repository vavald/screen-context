#!/bin/zsh
# Builds the Helper, signs it and (re)starts it from ~/Applications.
set -euo pipefail
cd "${0:A:h}"
swift build -c release
app=~/Applications/"Screen Context.app"
pkill -x ScreenContext || true
mkdir -p "$app/Contents/MacOS"
cp .build/release/ScreenContext "$app/Contents/MacOS/"
cp Info.plist "$app/Contents/"
# A stable signature keeps the Accessibility and Screen Recording grants across rebuilds.
codesign --force --sign 8B891B5864B932C0DC92B425F8C04D3CCF9F41A7 "$app"
open "$app"
