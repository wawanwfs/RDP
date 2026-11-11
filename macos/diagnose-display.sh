#!/usr/bin/env bash
# Read-only diagnostic for black Apple Screen Sharing VNC frames.
# Never modifies SSH, TCC, SIP, ARD privileges, passwords or login sessions.
set -Eeuo pipefail
user=wfsremote
if [ "$#" -gt 0 ]; then user="$1"; fi
[[ "$user" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] || { echo "Invalid user." >&2; exit 2; }
test "$(uname -s)" = Darwin || { echo "Must run on macOS over SSH." >&2; exit 2; }

echo '== WFS macOS display diagnostic (read only) =='
echo "OS: $(sw_vers -productVersion) / $(uname -m)"
echo "SSH user: $(id -un)"
echo "Desktop console owner: $(stat -f %Su /dev/console 2>/dev/null || echo unavailable)"
echo "Remote identity: $user"

echo
echo '== WindowServer and graphical login processes =='
ps -A -o user= -o comm= |
  awk '$2 ~ /(^|\/)(WindowServer|loginwindow|Finder|screensharingd|ARDAgent)$/ {print $1, $2}' |
  head -n 18 || true

echo
echo '== CoreGraphics active display enumeration =='
if command -v swift >/dev/null 2>&1; then
  swift -e '
import CoreGraphics
var count: UInt32 = 0
let result = CGGetActiveDisplayList(0, nil, &count)
print("Display enumeration status:", result.rawValue)
print("Active display count:", count)
if count > 0 && count < 12 {
    var list = [CGDirectDisplayID](repeating: 0, count: Int(count))
    var filled: UInt32 = 0
    if CGGetActiveDisplayList(count, &list, &filled) == .success {
        for screen in list.prefix(Int(filled)) {
            print("Display:", screen, "resolution:", CGDisplayPixelsWide(screen), "x", CGDisplayPixelsHigh(screen))
        }
    }
}
' 2>&1 | head -n 30 || echo 'CoreGraphics unavailable in this SSH session.'
else
  echo 'Swift runtime unavailable; display enumeration not attempted.'
fi

echo
echo '== Screen capture availability (no image retained) =='
tempdir="$(mktemp -d)"
chmod 700 "$tempdir"
trap 'rm -rf "$tempdir"' EXIT
if command -v screencapture >/dev/null 2>&1 &&
   screencapture -x "$tempdir/probe.png" >/dev/null 2>&1 &&
   test -s "$tempdir/probe.png"; then
  echo 'screencapture created image bytes, but visible pixels are unverified.'
  sips -g pixelWidth -g pixelHeight "$tempdir/probe.png" 2>/dev/null |
    grep -E 'pixelWidth:|pixelHeight:' || true
else
  echo 'screencapture unavailable/blocked for this user (may be a TCC restriction).'
fi

echo
echo '== Screen Sharing service and socket =='
if launchctl print system/com.apple.screensharing >/dev/null 2>&1; then
  echo 'Screen Sharing launchd service: present'
else
  echo 'Screen Sharing launchd service: unavailable'
fi
if nc -G 2 -z 127.0.0.1 5900 >/dev/null 2>&1; then
  echo 'VNC TCP 5900: listening (not proof of a working framebuffer)'
else
  echo 'VNC TCP 5900: unavailable'
fi
echo
echo 'Notes: A screenshot from SSH may be blocked even with an active display.'
echo 'Active display detection does not prove VNC is non-black. This is only diagnosis.'
echo 'No credentials requested; SSH and system configuration left unchanged.'
