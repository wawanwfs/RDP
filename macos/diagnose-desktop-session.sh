#!/usr/bin/env bash
# WFS macOS: distinguish blank console framebuffer from an uninitialized
# GUI user session. Safe default is read-only. No TCC/SIP changes.
set -Eeuo pipefail
user=wfsremote
if test "$#" -gt 0; then user="$1"; fi
mode=inspect
if test "$#" -gt 1; then mode="$2"; fi
[[ "$user" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] || { echo 'Invalid username' >&2; exit 2; }
case "$mode" in inspect|--open-finder) ;; *) echo 'Usage: diagnose-desktop-session.sh [user] [--open-finder]' >&2; exit 2;; esac
test "$(uname -s)" = Darwin || { echo 'Must run on macOS' >&2; exit 2; }
id "$user" >/dev/null 2>&1 || { echo 'User does not exist' >&2; exit 2; }
uid="$(id -u "$user")"
console="$(stat -f %Su /dev/console 2>/dev/null || echo unknown)"
echo '== WFS macOS GUI-session inspection =='
echo "macOS: $(sw_vers -productVersion) / $(uname -m)"
echo "SSH user: $(id -un)"
echo "Console user: $console"
echo "Target user: $user (UID $uid)"

echo
echo '== GUI bootstrap context =='
gui_ready=no
if launchctl print "gui/$uid" >/dev/null 2>&1; then
  gui_ready=yes
  echo "launchctl gui/$uid: EXISTS"
else
  echo "launchctl gui/$uid: NOT AVAILABLE (GUI login may be incomplete)"
fi

echo
echo '== User-owned desktop services =='
ps -A -o user= -o comm= | awk -v target="$user" '
  $1 == target && ($2 ~ /(^|\/)(Finder|Dock|SystemUIServer|loginwindow|ARDAgent)$/) {
    print $1, $2
  }'
for app in Finder Dock SystemUIServer; do
  if ps -A -o user= -o comm= | awk -v target="$user" -v exe="$app" '
      $1==target && $2 ~ ("/" exe "$") {found=1} END {exit found?0:1}'; then
    echo "$user $app: running"
  else
    echo "$user $app: NOT RUNNING"
  fi
done

if test "$mode" = --open-finder; then
  test "$(id -un)" = "$user" ||
    { echo 'Refusing GUI launch as another account. SSH as the target user.' >&2; exit 3; }
  test "$console" = "$user" && test "$gui_ready" = yes ||
    { echo 'Not starting Finder: GUI bootstrap or console ownership does not match.' >&2; exit 3; }
  echo
  echo "Attempting Finder launch within user $user existing GUI bootstrap..."
  launchctl asuser "$uid" /usr/bin/open -a Finder ||
    { echo 'Finder launch was rejected by macOS'; exit 4; }
  sleep 3
  ps -A -o user= -o comm= |
    awk -v target="$user" '$1 == target && $2 ~ /\/Finder$/ {print "Finder process:", $1, $2}'
  echo 'Finder start request sent. Reconnect VNC to check visual result.'
  # Do not change sharing privileges, loginwindow, Dock, SIP or TCC.
  exit 0
fi

echo
echo '== Local screen pixel statistics (private image deleted immediately) =='
tmp="$(mktemp -d)"
chmod 700 "$tmp"
trap 'rm -rf "$tmp"' EXIT
if screencapture -x "$tmp/screen.png" >/dev/null 2>&1 &&
   test -s "$tmp/screen.png"; then
  sips -g pixelWidth -g pixelHeight "$tmp/screen.png" 2>/dev/null |
    grep -E 'pixelWidth:|pixelHeight:' || true
  if command -v swift >/dev/null 2>&1; then
    swift -e '
import AppKit
let imagePath = CommandLine.arguments.last!
let input = try? Data(contentsOf: URL(fileURLWithPath: imagePath))
guard let bytes = input,
      let bitmap = NSBitmapImageRep(data: bytes),
      bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0 else {
  print("Pixel analysis not available")
  exit(0)
}
let grid = 12
var dark = 0
var samples = 0
for row in 0..<grid {
  for column in 0..<grid {
    let x = column * (bitmap.pixelsWide - 1) / (grid - 1)
    let y = row * (bitmap.pixelsHigh - 1) / (grid - 1)
    if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(NSColorSpace.deviceRGB) {
      samples += 1
      if max(color.redComponent, color.greenComponent, color.blueComponent) < 0.06 {
        dark += 1
      }
    }
  }
}
if samples > 0 {
  let percent = (100 * dark) / samples
  print("Near-black pixel sample:", dark, "/", samples, "(", percent, "%)")
  if percent > 95 {
    print("NOTICE: The SSH screenshot itself is nearly all black.")
  } else {
    print("NOTICE: SSH screenshot has nonblack samples. VNC may be showing a different session or be unable to capture its frames.")
  }
}
' "$tmp/screen.png" || echo 'Pixel analysis could not run with Swift.'
  else
    echo 'Swift unavailable; only screenshot dimensions checked.'
  fi
else
  echo 'Screenshot unavailable from this SSH account. May be a privacy/GUI restriction.'
fi

echo
echo 'Next actions:'
if test "$console" = "$user" && test "$gui_ready" = yes; then
  echo 'If Finder is absent, optionally run: bash macos/diagnose-desktop-session.sh wfsremote --open-finder'
else
  echo 'No matching complete GUI session; launching Finder from SSH cannot create a supported graphical login.'
fi
echo 'Read-only check complete. No image stored, no password changed.'
