#!/usr/bin/env bash
# Install actual MetaTrader Windows terminals in an isolated Wine prefix.
# Only publisher-hosted binaries; status requires a verified terminal executable.
# No credentials, broker login, trading activity or auto-login are configured.
set -Eeuo pipefail
container=wfs-linux-webtop
dir="$RUNNER_TEMP/wfs-linux"
report="$dir/trading-status.tsv"
mkdir -p "$dir"
: > "$report"
say() { echo "[WFS Trading] $*"; }
record() {
  printf '%s\t%s\n' "$1" "$2" >> "$report"
  say "$1: $2"
}
choice="${WFS_METATRADER:-none}"
case "$choice" in none) exit 0;; mt4|mt5|both) ;; *) echo "::error::Invalid trading selection" >&2; exit 1;; esac
distro="${WFS_DISTRO:-ubuntu}"
[ "$distro" = igos-nusantara ] && distro=ubuntu  # outside VM, not guest
if [ "$distro" = alpine ]; then
  case "$choice" in
    mt4|both) record "MetaTrader 4" "UNSUPPORTED (Alpine musl: Wine compatibility not verified)" ;;
  esac
  case "$choice" in
    mt5|both) record "MetaTrader 5" "UNSUPPORTED (Alpine musl: Wine compatibility not verified)" ;;
  esac
  exit 0
fi
if [ "${WFS_REMOTE:-}" = novnc ]; then
  user=abc
else
  user="${WFS_RDP_USERNAME:-RDP}"
fi
docker inspect "$container" >/dev/null
# Package installation uses the actual distro; do not run MetaQuotes shell
# installers as root and do not add random third-party Wine APT repositories.
say "Installing Wine / Xvfb prerequisites in $distro (selected=$choice; desktop user=$user)"
if ! timeout 520 docker exec -i -u 0 "$container" /bin/bash -s -- "$distro" "$choice" <<'PREREQUISITES'
set -Eeuo pipefail
distro="$1"
choice="$2"
case "$distro" in
  ubuntu|debian)
    export DEBIAN_FRONTEND=noninteractive
    if [ "$choice" = mt4 ] || [ "$choice" = both ]; then
      # MT4 requires 32-bit support. This can add significant dependencies.
      dpkg --add-architecture i386
    fi
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
      wine wine64 xvfb xauth curl ca-certificates cabextract fonts-liberation
    if [ "$choice" = mt4 ] || [ "$choice" = both ]; then
      apt-get install -y -qq --no-install-recommends wine32:i386 ||
        echo "::warning::Wine i386 runtime not installed; MT4 may fail and will be verified independently."
    fi
    ;;
  fedora)
    dnf install -y wine xorg-x11-server-Xvfb xauth curl ca-certificates
    ;;
  arch)
    pacman -Sy --needed --noconfirm wine xorg-server-xvfb xorg-xauth curl ca-certificates
    ;;
  *) echo "Unsupported distro: $distro" >&2; exit 2 ;;
esac
command -v wine
command -v xvfb-run
wine --version
PREREQUISITES
then
  for app in mt4 mt5; do
    case "$choice" in "$app"|both)
      record "MetaTrader ${app#mt}" "FAILED (Wine/Xvfb package preparation failed; see step log)" ;;
    esac
  done
  exit 1
fi
say "Downloading official Exness MT4 and MetaQuotes MT5 installers into isolated Wine prefixes."
failed=0
for app in mt4 mt5; do
  if [ "$choice" != "$app" ] && [ "$choice" != both ]; then continue; fi
  if [ "$app" = mt4 ]; then label="MetaTrader 4"; else label="MetaTrader 5"; fi
  # MT4 upstream historically sometimes supplied an MT5 installer under the
  # mt4setup name. Use a broker-hosted MT4 package and verify the binary.
  # For broker-branded MT4, use broker's authorized installer manually when needed.
  if docker exec -i -u 0 "$container" /bin/bash -s -- "$app" "$user" <<'INSTALL'
set -Eeuo pipefail
app="$1"
account="$2"
id "$account" >/dev/null
home="$(getent passwd "$account" | cut -d: -f6)"
test -n "$home" && test -d "$home"
prefix="$home/.wfs-metatrader/$app"
install_dir="/tmp/wfs-metatrader-install-$app"
mkdir -p "$prefix" "$install_dir" "$home/Desktop"
chown -R "$account" "$home/.wfs-metatrader" "$home/Desktop"
chmod 700 "$home/.wfs-metatrader"
trap 'rm -rf "$install_dir"' EXIT
if [ "$app" = mt4 ]; then
  # Current generic MetaQuotes MT4 links may resolve to an MT5 installer.
  # This source is the Windows MT4 executable linked by Exness official Help Center.
  url="https://download.terminal.free/cdn/web/exness.technologies.ltd/mt4/exness4setup.exe"
else
  # MetaQuotes installer has been proven to finish under Wine on this image.
  # The Exness broker installer was also tested but its /auto mode stalled.
  # Installing a binary DOES NOT establish MT5 Wine GUI runtime compatibility.
  url="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
fi
installer="$install_dir/${app}setup.exe"
curl --fail --location --silent --show-error --retry 3 --retry-all-errors \
  --connect-timeout 30 --max-time 150 --max-filesize 100000000 \
  "$url" --output "$installer"
test "$(stat -c %s "$installer")" -gt 1000000
test "$(head -c 2 "$installer")" = MZ || { echo "Invalid PE header for MetaQuotes executable" >&2; exit 31; }
sha256sum "$installer" | cut -d' ' -f1 > "$home/.wfs-metatrader/$app-installer.sha256"
chown "$account" "$home/.wfs-metatrader/$app-installer.sha256"
chmod 644 "$installer"
# In CI Wine needs an X display even when installing without interaction.
# No broker credentials are accessed. Installer /auto is documented for MT5;
# for MT4 it is a best effort; a missing terminal executable is FAILURE.
runuser -u "$account" -- env \
  HOME="$home" USER="$account" WINEPREFIX="$prefix" WINEARCH=win64 \
  WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=" \
  timeout 85 xvfb-run -a -s '-screen 0 1280x800x24 -nolisten tcp' \
  wineboot -u || { echo "Wine initialization failed" >&2; exit 32; }
# Timeout is not proof of failure: some installers auto-launch the terminal
# and stay running. The executable check below is the acceptance gate.
install_timeout=330
[ "$app" = mt4 ] && install_timeout=120
set +e
runuser -u "$account" -- env \
  HOME="$home" USER="$account" WINEPREFIX="$prefix" WINEARCH=win64 \
  WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=" \
  timeout --signal=TERM --kill-after=8 "$install_timeout" \
  xvfb-run -a -s '-screen 0 1280x800x24 -nolisten tcp' \
  wine "$installer" /auto
result=$?
set -e
echo "[WFS Trading] $app installer exit=$result (binary verification follows)"
# Stop leftover wine processes in this prefix but leave other apps untouched.
runuser -u "$account" -- env HOME="$home" WINEPREFIX="$prefix" \
  WINEDEBUG=-all wineserver -k >/dev/null 2>&1 || true
if [ "$app" = mt5 ]; then
  terminal="$(find "$prefix/drive_c" -type f -iname terminal64.exe -path '*MetaTrader 5*' -print -quit 2>/dev/null || true)"
else
  terminal="$(find "$prefix/drive_c/Program Files" "$prefix/drive_c/Program Files (x86)" -type f -iname terminal.exe -print -quit 2>/dev/null || true)"
  # Ignore mistaken MT5 bootstrap installers that leave 64-bit terminal under
  # the same fresh prefix. An Exness-branded folder name is supported.
  if [ -n "$(find "$prefix/drive_c" -type f -iname terminal64.exe -path '*MetaTrader 5*' -print -quit 2>/dev/null || true)" ]; then
    echo "MT4 installer resolved to MT5; refusing false-positive MT4 success." >&2
    exit 33
  fi
fi
if [ -z "$terminal" ] || [ ! -s "$terminal" ]; then
  echo "MetaTrader $app terminal missing after automated Wine install (installer exit $result)." >&2
  if [ "$app" = mt4 ]; then
    # The Exness MT4 bootstrap may require a real graphical session under Wine.
    # Preserve the verified-source PE setup for the signed-in desktop user;
    # do NOT report MT4 as INSTALLED when terminal.exe is absent.
    pending_dir="$home/.wfs-metatrader/pending"
    pending_file="$pending_dir/mt4setup.exe"
    mkdir -p "$pending_dir"
    cp "$installer" "$pending_file"
    chmod 600 "$pending_file"
    chown "$account" "$pending_dir" "$pending_file"
    cat > /usr/local/bin/wfs-mt4-install <<LAUNCH
#!/bin/sh
export WINEPREFIX="$prefix"
export WINEDEBUG=-all
exec wine "$pending_file"
LAUNCH
    chmod 755 /usr/local/bin/wfs-mt4-install
    mkdir -p /usr/share/applications
    cat > /usr/share/applications/wfs-mt4-install.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install MetaTrader 4 (WFS)
Comment=Complete original Exness MT4 installer in interactive Wine GUI
Exec=/usr/local/bin/wfs-mt4-install
Terminal=false
Categories=Office;Finance;
DESKTOP
    cp /usr/share/applications/wfs-mt4-install.desktop "$home/Desktop/wfs-mt4-install.desktop"
    chown "$account" "$home/Desktop/wfs-mt4-install.desktop"
    chmod 755 "$home/Desktop/wfs-mt4-install.desktop"
    test -s "$pending_file" && test -x /usr/local/bin/wfs-mt4-install
    test -s "$home/Desktop/wfs-mt4-install.desktop"
    echo "PENDING_INTERACTIVE: MT4 downloaded from official Exness CDN, but Wine GUI setup still requires user action." >&2
    exit 42
  fi
  exit 34
fi
# Restrict launcher to the original user; do not interpolate input URLs or
# credentials into .desktop entries. Fixed launcher name is safe.
launcher="/usr/local/bin/wfs-$app"
cat > "$launcher" <<LAUNCH
#!/usr/bin/env bash
set -Eeuo pipefail
export WINEPREFIX="$prefix"
export WINEDEBUG=-all
exec wine "$terminal" "\$@"
LAUNCH
chmod 755 "$launcher"
title="MetaTrader 5"
[ "$app" = mt4 ] && title="MetaTrader 4"
cat > "/usr/share/applications/wfs-$app.desktop" <<DESKTOP
[Desktop Entry]
Version=1.0
Type=Application
Name=$title (WFS)
Comment=Windows trading terminal under Wine
Exec=$launcher
Terminal=false
Categories=Office;Finance;
DESKTOP
# Wine may already have added an official, icon-bearing desktop launcher.
# Keep the desktop clean instead of adding a generic duplicate "(WFS)" icon.
native_shortcut=""
for shortcut in "$home/Desktop/"*.desktop; do
  [ -f "$shortcut" ] || continue
  case "$shortcut" in */wfs-*.desktop) continue ;; esac
  if grep -Fiq "$title" "$shortcut" 2>/dev/null; then
    native_shortcut="$shortcut"
    break
  fi
done
if [ -n "$native_shortcut" ]; then
  echo "[WFS Trading] Existing native $title Desktop icon kept; no duplicate WFS icon."
else
  cp "/usr/share/applications/wfs-$app.desktop" "$home/Desktop/wfs-$app.desktop"
  chmod +x "$home/Desktop/wfs-$app.desktop"
  chown "$account" "$home/Desktop/wfs-$app.desktop"
  native_shortcut="$home/Desktop/wfs-$app.desktop"
fi
test -x "$launcher" && test -s "$terminal" && test -s "$native_shortcut"
echo "PASS: $title binary, menu launcher, and one desktop shortcut verified."
INSTALL
  then
    record "$label" "INSTALLED (Wine executable + Desktop shortcut verified; GUI/account login not yet tested)"
  else
    rc=$?
    if [ "$app" = mt4 ] && [ "$rc" -eq 42 ]; then
      record "$label" "PENDING_INTERACTIVE (Exness setup + Wine launcher saved to desktop; actual terminal not installed)"
    else
      record "$label" "FAILED (Wine installer exit $rc; no verified $app terminal)"
      failed=$((failed+1))
    fi
  fi
done
# Keep a legal, account-free browser alternative when a Windows terminal fails
# to render under Wine. WebTerminal does NOT support desktop EAs/scripts.
docker exec -i -u 0 "$container" /bin/sh -s <<'WEB'
set -eu
browser="$(cat /etc/wfs-browser-executable 2>/dev/null || true)"
if [ -n "$browser" ] && [ -x "$browser" ]; then
  cat > /usr/local/bin/wfs-metatrader-web <<'SCRIPT'
#!/bin/sh
browser="$(cat /etc/wfs-browser-executable)"
test -x "$browser" || { echo "Selected browser missing"; exit 1; }
exec "$browser" https://web.metatrader.app/
SCRIPT
  chmod 755 /usr/local/bin/wfs-metatrader-web
  mkdir -p /usr/share/applications
  cat > /usr/share/applications/wfs-metatrader-web.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=MetaTrader WebTerminal (WFS fallback)
Comment=Browser-based trading; does not support desktop Expert Advisors
Exec=/usr/local/bin/wfs-metatrader-web
Terminal=false
Categories=Network;Finance;
DESKTOP
  echo "[WFS Trading] Optional browser-only WebTerminal menu shortcut ready (not a desktop EA replacement)."
fi
WEB
say "Wine selected app installation finished; failed=$failed. Per-app results are in Actions Summary."
[ "$failed" -eq 0 ]
