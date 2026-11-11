#!/usr/bin/env bash
# Run read-only screenshot browser mirror from an existing authenticated SSH.
# No Finder, VNC, SSH, TCC, SIP, or login configuration changes.
set -Eeuo pipefail
umask 077
me="$(id -un)"
profile="$HOME/.wfs-preview"
if test "$#" -gt 0 && test "$1" = --stop; then
  if test -s "$profile/ssh-preview.pid"; then
    pid="$(cat "$profile/ssh-preview.pid")"
    if [[ "$pid" =~ ^[0-9]+$ ]]; then kill "$pid" >/dev/null 2>&1 || true; fi
  fi
  rm -f "$profile/ssh-preview.pid" "$profile/login-secret"
  echo "[WFS Preview] SSH-started viewer stopped; SSH/VNC unaffected."
  exit 0
fi
test "$(uname -s)" = Darwin
command -v curl >/dev/null
command -v python3 >/dev/null
ip="$(printenv WFS_PREVIEW_IP 2>/dev/null || true)"
if test -z "$ip" && command -v tailscale >/dev/null 2>&1; then
  ip="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
fi
if test -z "$ip"; then
  for client in /opt/homebrew/bin/tailscale /usr/local/bin/tailscale /usr/bin/tailscale; do
    if test -x "$client"; then ip="$("$client" ip -4 2>/dev/null | head -n1 || true)"; break; fi
  done
fi
if test -z "$ip"; then
  echo "Set WFS_PREVIEW_IP=100.x.x.x (from Actions Summary) and retry." >&2
  exit 3
fi
mkdir -p "$profile"; chmod 700 "$profile"
if test -f "$0"; then
  cp "$0" "$profile/launch-preview-ssh.sh"
  chmod 700 "$profile/launch-preview-ssh.sh"
fi
if nc -G 2 -z "$ip" 6081 >/dev/null 2>&1; then
  echo "[WFS Preview] Existing viewer detected on $ip:6081; use its configured login."
  exit 0
fi
curl -fsSL https://raw.githubusercontent.com/wawanwfs/RDP/main/macos/gui-preview.py \
  -o "$profile/gui-preview.py"
chmod 600 "$profile/gui-preview.py"
printf 'Choose a NEW private browser password (12+ characters): '
IFS= read -r -s password
printf '\n'
length="$(printf %s "$password" | wc -c | tr -d ' ')"
test "$length" -ge 12 || { echo "Password too short" >&2; exit 4; }
printf '%s' "$password" > "$profile/login-secret"
chmod 600 "$profile/login-secret"
unset password
nohup python3 "$profile/gui-preview.py" \
  --host "$ip" --port 6081 --username "$me" --password-file "$profile/login-secret" \
  > "$profile/preview.log" 2>&1 < /dev/null &
pid="$!"
printf '%s\n' "$pid" > "$profile/ssh-preview.pid"
ready=no
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if nc -G 2 -z "$ip" 6081 >/dev/null 2>&1; then ready=yes; break; fi
  kill -0 "$pid" >/dev/null 2>&1 || break
  sleep 1
done
test "$ready" = yes || { echo "Preview did not start; inspect $profile/preview.log" >&2; exit 5; }
python3 - "$ip" "$me" "$profile/login-secret" <<'PY'
import base64,struct,sys,urllib.request
ip,username,path=sys.argv[1:]
pwd=open(path,encoding="utf-8").read().strip()
auth=base64.b64encode((username+":"+pwd).encode()).decode()
req=urllib.request.Request("http://"+ip+":6081/frame.png",headers={"Authorization":"Basic "+auth})
try:
    with urllib.request.urlopen(req,timeout=18) as response: png=response.read()
    if not png.startswith(b"\x89PNG\r\n\x1a\n"): raise ValueError("No PNG")
    width,height=struct.unpack(">II",png[16:24])
    print(f"[WFS Preview] PASS: authenticated screenshot {width}x{height}, {len(png)} bytes")
except Exception as exc:
    print("[WFS Preview] Frame not verified:",type(exc).__name__,str(exc))
    print("[WFS Preview] Listener exists; macOS may restrict screen capture for this session.")
PY
echo "[WFS Preview] Open http://$ip:6081/ on Windows joined to the same Tailnet."
echo "[WFS Preview] Username: $me; password: the NEW password chosen above."
echo "[WFS Preview] READ-ONLY: native mouse and keyboard require separate permissions."
echo "[WFS Preview] Stop: bash $profile/launch-preview-ssh.sh --stop"
