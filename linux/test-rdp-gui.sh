#!/usr/bin/env bash
# CI-only actual xrdp/Xorg/Xfce graphical login verification.
# Uses dummy credentials from the smoke test. Does NOT print passwords.
set -Eeuo pipefail
[ "$WFS_REMOTE" = both ] || { echo "xrdp GUI smoke requires both mode" >&2; exit 1; }
secret="$RUNNER_TEMP/wfs-linux/rdp-password"
[ -s "$secret" ] || { echo "Missing CI password file" >&2; exit 1; }
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends freerdp3-x11 xvfb
if command -v xfreerdp3 >/dev/null; then
  client=xfreerdp3
elif command -v xfreerdp >/dev/null; then
  client=xfreerdp
else
  echo "FreeRDP X11 client not installed" >&2
  exit 1
fi
test_user="$WFS_RDP_USERNAME"
echo "[WFS RDP Smoke] Graphical client will authenticate to xrdp as $test_user (password masked)."
log="$RUNNER_TEMP/wfs-rdp-gui-client.log"
(
  set +e
  # Only CI dummy credentials are used here; no user secrets.
  # FreeRDP 3 in Ubuntu 24.04 does not accept /from-stdin:force on
  # all versions; pass the generated *test* password to the CLI instead.
  dummy_password="$(cat "$secret")"
  timeout 80 xvfb-run -a -s '-screen 0 1024x768x24' \
    "$client" /v:127.0.0.1:13389 /u:"$test_user" /p:"$dummy_password" \
    /cert:ignore /sec:tls /size:1024x768 \
    /log-level:WARN > "$log" 2>&1
  unset dummy_password
  exit 0
) &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
ready=no
desktop="${WFS_DESKTOP:-xfce}"
case "$desktop" in
  xfce) checks=(xfce4-session xfwm4 xfdesktop) ;;
  kde) checks=(plasmashell kwin_x11) ;;
  mate) checks=(mate-session marco mate-panel) ;;
  i3) checks=(i3) ;;
  lxqt) checks=(lxqt-session lxqt-panel openbox) ;;
  *) echo "Unknown X11 smoke desktop: $desktop" >&2; exit 3 ;;
esac
echo "[WFS RDP Smoke] Verifying $desktop: ${checks[*]}"
for attempt in $(seq 1 50); do
  match=yes
  for proc in "${checks[@]}"; do
    if ! docker exec -u 0 wfs-linux-webtop pgrep -u "$test_user" -x "$proc" >/dev/null 2>&1; then
      match=no
      break
    fi
  done
  if [ "$match" = yes ]; then
    ready=yes
    break
  fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 2
done

if [ "$ready" != yes ]; then
  echo "::error::Actual GUI login did not launch all required $desktop processes (${checks[*]}) for $test_user."
  echo "[WFS RDP Smoke] FreeRDP client diagnostics (no passwords):"
  tail -50 "$log" || true
  echo "[WFS RDP Smoke] xrdp-sesman:"
  docker exec -u 0 wfs-linux-webtop /bin/sh -c 'tail -65 /var/log/xrdp-sesman.log' || true
  echo "[WFS RDP Smoke] user startup:"
  docker exec -u 0 wfs-linux-webtop /bin/sh -c 'tail -60 "$1/.wfs-xrdp-session.log" 2>/dev/null || true' -- "$(docker exec -u 0 wfs-linux-webtop getent passwd "$test_user" | cut -d: -f6)" || true
  exit 1
fi
echo "PASS: FreeRDP graphical session connected as $test_user and spawned all selected $desktop processes."
echo "PASS: verified selected $desktop Xorg session — TCP/PAM alone are no longer accepted."
