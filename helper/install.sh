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
# A code-signing certificate keeps the Accessibility and Screen Recording grants across rebuilds. Without one the app
# is signed ad hoc, which macOS takes for a new app on each rebuild: the old grants would show as on yet not work, so
# they're cleared and the app asks again.
identity=$(security find-identity -v -p codesigning | awk '/^ *1\)/ { print $2 }')
if [[ -n $identity ]]; then
  codesign --force --sign "$identity" "$app"
else
  codesign --force --sign - "$app"
  tccutil reset Accessibility io.github.vavald.ScreenContext 2>/dev/null || true
  tccutil reset ScreenCapture io.github.vavald.ScreenContext 2>/dev/null || true
fi
open "$app"
