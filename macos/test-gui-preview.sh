#!/usr/bin/env bash
# Self-contained real macOS GUI preview acceptance on localhost only.
# No Tailscale secrets, no third-party services, no image upload to GitHub.
set -Eeuo pipefail
test "$(uname -s)" = Darwin
temp="$(mktemp -d)"
chmod 700 "$temp"
pid=""
cleanup() {
  local result="$?"
  trap - EXIT
  if test -n "$pid"; then kill "$pid" >/dev/null 2>&1 || true; wait "$pid" 2>/dev/null || true; fi
  rm -rf "$temp"
  exit "$result"
}
trap cleanup EXIT
password="ci-testing-strong-password-2026"
printf '%s' "$password" > "$temp/secret"
chmod 600 "$temp/secret"
/usr/bin/python3 macos/gui-preview.py \
  --host 127.0.0.1 --port 6089 \
  --username wfsremote --password-file "$temp/secret" \
  > "$temp/server.log" 2>&1 &
pid="$!"
ready=no
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if nc -G 2 -z 127.0.0.1 6089 >/dev/null 2>&1; then ready=yes; break; fi
  kill -0 "$pid" >/dev/null 2>&1 || break
  sleep 1
done
test "$ready" = yes || { echo "Preview listener missing" >&2; cat "$temp/server.log"; exit 1; }
url="http://127.0.0.1:6089"
unauth="$(curl -s --noproxy '*' -o /dev/null -w '%{http_code}' "$url/health")"
test "$unauth" = 401
echo "PASS: unauthenticated HTTP denied (401)."
# Password is never printed in Actions logs, only stored inside 0700 test dir.
status="$(curl -s --noproxy '*' -u "wfsremote:$password" -o /dev/null -w '%{http_code}' "$url/")"
test "$status" = 200
status="$(curl -s --noproxy '*' -u "wfsremote:$password" -o /dev/null -w '%{http_code}' -X POST "$url/")"
test "$status" = 405
echo "PASS: authenticated view returned 200; mutation POST denied (405)."
curl -fsS --noproxy '*' -u "wfsremote:$password" "$url/frame.png" -o "$temp/frame.png"
python3 - "$temp/frame.png" <<'PY'
import sys, pathlib, struct
data=pathlib.Path(sys.argv[1]).read_bytes()
assert data.startswith(b"\x89PNG\r\n\x1a\n"), "No PNG returned"
w,h=struct.unpack(">II",data[16:24])
assert 64 <= w <= 10000 and 64 <= h <= 10000
print(f"PASS: macOS native screencapture frame delivered over authenticated HTTP: {w}x{h}, {len(data)} bytes")
PY
curl -fsS --noproxy '*' -u "wfsremote:$password" "$url/health" |
  python3 -c 'import json,sys; j=json.load(sys.stdin); assert j["mode"]=="read_only" and j["frames"]>=1 and j["screenshot_ok"]; print("PASS: preview health reports real successful capture")'
echo "NOTE: screenshot bytes verified and removed during cleanup; mouse/keyboard control NOT tested or supported."
