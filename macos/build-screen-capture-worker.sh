#!/usr/bin/env bash
# Build native ScreenCaptureKit helper. Does not grant Screen Recording consent.
set -Eeuo pipefail
test "$(uname -s)" = Darwin || { echo "macOS only" >&2; exit 2; }
root="$(cd "$(dirname "$0")" && pwd)"
target="$HOME/.wfs-preview/WFS Capture.app"
if test "$#" -gt 0; then target="$1"; fi
mkdir -p "$target/Contents/MacOS"
cat > "$target/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>WFS Capture</string>
<key>CFBundleDisplayName</key><string>WFS Capture</string>
<key>CFBundleIdentifier</key><string>tech.wfs.macos.capture</string>
<key>CFBundleExecutable</key><string>WFS-Capture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Stream the macOS display to your private WFS remote desktop, with your authorization.</string>
</dict></plist>
PLIST
swiftc -parse-as-library -O -o "$target/Contents/MacOS/WFS-Capture" "$root/ScreenCaptureWorker.swift" \
  -framework ScreenCaptureKit -framework AppKit -framework CoreImage -framework CoreMedia -framework CoreVideo
chmod 755 "$target/Contents/MacOS/WFS-Capture"
/usr/bin/codesign --force --sign - "$target" >/dev/null 2>&1
/usr/bin/codesign --verify "$target"
echo "[WFS Capture] Native helper built and signed. Screen Recording still requires explicit authorization."
