#!/usr/bin/env bash
# Real MT5 X11 smoke test on a disposable display. Never logs into a broker.
set -Eeuo pipefail
container=wfs-linux-webtop
user="$WFS_RDP_USERNAME"
[ "$WFS_REMOTE" = novnc ] && user=abc
echo "[WFS MT5 GUI] Probing main window as $user on isolated Xvfb"
docker exec -i -u 0 "$container" /bin/bash -s -- "$user" <<'IN_CONTAINER'
set -Eeuo pipefail
user="$1"
home="$(getent passwd "$user" | cut -d: -f6)"
test -n "$home" && test -d "$home"
prefix="$home/.wfs-metatrader/mt5"
terminal="$(find "$prefix/drive_c" -type f -iname terminal64.exe -path '*MetaTrader 5*' -print -quit 2>/dev/null || true)"
test -n "$terminal" && test -s "$terminal"
if ! command -v xwininfo >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends x11-utils
fi
runuser -u "$user" -- env HOME="$home" USER="$user" WINEPREFIX="$prefix" \
  WINEDEBUG=-all WFS_MT5_EXE="$terminal" \
  timeout --signal=TERM --kill-after=8 85 \
  xvfb-run -a -s '-screen 0 1280x800x24 -nolisten tcp' /bin/bash -s <<'SMOKE'
set -Eeuo pipefail
wine "$WFS_MT5_EXE" >/dev/null 2>&1 &
wine_pid=$!
cleanup() { kill "$wine_pid" >/dev/null 2>&1 || true; wineserver -k >/dev/null 2>&1 || true; }
trap cleanup EXIT
for i in $(seq 1 32); do
  windows="$(xwininfo -root -tree 2>/dev/null || true)"
  if printf '%s\n' "$windows" | grep -iE '"[^"]*(MetaTrader 5|MetaTrader5|Exness MT5)[^"]*"' >/dev/null; then
    echo "[WFS MT5 GUI] PASS: MetaTrader 5 main-window visible in X11."
    exit 0
  fi
  if ! kill -0 "$wine_pid" 2>/dev/null; then
    echo "[WFS MT5 GUI] FAIL: Wine exited before main window appeared." >&2
    printf '%s\n' "$windows" | tail -30 >&2
    exit 21
  fi
  sleep 2
done
echo "[WFS MT5 GUI] FAIL: installed terminal64.exe did not open a MetaTrader main window." >&2
printf '%s\n' "$windows" | grep -E '^ *0x' | tail -30 >&2 || true
echo "[WFS MT5 GUI] A debugger alert titled terminal64.exe is not an accepted GUI." >&2
exit 22
SMOKE
IN_CONTAINER
