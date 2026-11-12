#!/usr/bin/env bash
# Read-only VNC troubleshooting from SSH. Does not change accounts,
# Screen Sharing, SIP, TCC, passwords, or firewall settings.
set -Eeuo pipefail
user=wfsremote
if [ "$#" -ge 1 ]; then user="$1"; fi
[[ "$user" =~ ^[a-z][a-z0-9_-]{1,30}$ ]] || { echo "Invalid username" >&2; exit 2; }
test "$(uname -s)" = Darwin || { echo "Run on a Mac (over SSH)" >&2; exit 2; }
echo "== WFS macOS VNC (read-only) =="
echo "OS: $(sw_vers -productVersion) / $(uname -m)"
echo "SSH identity: $(id -un)"
console="$(stat -f %Su /dev/console 2>/dev/null || printf unavailable)"
echo "Console identity: $console"
echo "Remote identity: $user"
if [ "$console" != "$user" ]; then
  echo "NOTICE: VNC console and SSH login belong to different macOS accounts."
fi
id "$user" >/dev/null 2>&1 || { echo "Remote account missing"; exit 3; }
echo "== Remote Management account access =="
if value="$(dscl . -read "/Users/$user" dsAttrTypeNative:naprivs 2>/dev/null)"; then
  echo "ARD privilege attribute: present (NOT proof of VNC login)"
  echo "$value" | head -n 3
else
  echo "ARD privilege attribute: absent or unreadable"
fi
for group in com.apple.access_screensharing com.apple.access_ssh; do
  if dscl . -read "/Groups/$group" >/dev/null 2>&1; then
    if command -v dsmemberutil >/dev/null 2>&1; then
      echo "$group: $(dsmemberutil checkmembership -U "$user" -G "$group" 2>&1 || true)"
    else
      echo "$group: exists; group member test unavailable"
    fi
  else
    echo "$group: explicit local group absent or unreadable"
  fi
done
echo "== VNC security negotiation (localhost 5900) =="
python3 - <<'PY'
import socket
try:
    with socket.create_connection(("127.0.0.1",5900), timeout=4) as s:
        s.settimeout(4)
        banner=s.recv(12)
        print("Protocol:",repr(banner))
        if not banner.startswith(b"RFB "):
            raise ValueError("No RFB banner")
        s.sendall(b"RFB 003.008\n")
        first=s.recv(1)
        if not first: raise ValueError("Closed before method negotiation")
        count=first[0]
        if count==0: raise ValueError("Server offered zero security methods")
        if count>64: raise ValueError("Invalid method count")
        methods=bytearray()
        while len(methods)<count:
            part=s.recv(count-len(methods))
            if not part: raise ValueError("Closed during method negotiation")
            methods.extend(part)
        print("Security types:",list(methods))
        print("Apple authentication available:",any(m in methods for m in (30,33,35,36)))
        print("Classic VNC password type 2:",2 in methods)
        print("NOTE: This is NOT a login or desktop-control test.")
except (OSError, ValueError) as exc:
    print("VNC probe failed:",type(exc).__name__,str(exc))
PY
echo "== Service presence =="
if launchctl print system/com.apple.screensharing >/dev/null 2>&1; then
  echo "Apple Screen Sharing launchd service: registered"
else
  echo "Apple Screen Sharing launchd service: absent/unreadable"
fi
echo "== Recent Apple Screen Sharing input-denial counters (best effort) =="
if command -v log >/dev/null 2>&1; then
  # These specific messages do not include keystrokes; print counts only.
  # macOS unified log privacy policy may redact or omit relevant entries.
  tmp="$(mktemp -t wfs-vnc-denials)"
  trap 'rm -f "$tmp"' EXIT
  if /usr/bin/log show --last 3m --style compact --info \
      --predicate '(process == "screensharingd" OR process == "ScreensharingAgent") AND (eventMessage CONTAINS[c] "not allowed to post key" OR eventMessage CONTAINS[c] "ignore key event")' \
      >"$tmp" 2>/dev/null; then
    count="$(grep -Eic 'not allowed to post key|ignore key event' "$tmp" || true)"
    echo "Recent key-denial or guard events: ${count:-0} (not a definitive authorization check)"
  else
    echo "Screen Sharing log access unavailable (not proof of accepted input)."
  fi
else
  echo "macOS unified logging tool unavailable."
fi
echo "== macOS permission boundary =="
echo "Apple: Remote Management activated via kickstart may be view-only on macOS 10.14+."
echo "Apple: Screen Sharing cannot be enabled via kickstart on macOS 12.1+."
echo "Read: https://support.apple.com/en-me/guide/remote-desktop/apd8b1c65bd/mac"
echo "SSH unaffected. No password was requested or logged."
