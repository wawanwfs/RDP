#!/usr/bin/env bash
# Browser first: reuse preinstalled Chromium and configure its two extensions.
set -Eeuo pipefail
docker inspect wfs-linux-webtop >/dev/null
echo "[WFS Browser] Detecting bundled Chromium before considering any download."
docker exec -i -u 0 wfs-linux-webtop /bin/sh -s -- "$WFS_DISTRO" <<'IN_CONTAINER'
set -eu
distro="$1"
[ "$distro" = igos-nusantara ] && distro=ubuntu
export DEBIAN_FRONTEND=noninteractive
family="" browser="" action="reused"
# Chromium comes first even if Google Chrome happens to be installed as well.
for exe in chromium chromium-browser; do
  if command -v "$exe" >/dev/null 2>&1; then browser="$exe"; family=chromium; break; fi
done
if [ -z "$browser" ]; then
  for exe in google-chrome-stable google-chrome; do
    if command -v "$exe" >/dev/null 2>&1; then browser="$exe"; family=chrome; break; fi
  done
fi
if [ -z "$browser" ]; then
  action=installed
  case "$distro" in
    ubuntu|debian)
      # Ubuntu's chromium-browser fallback is snap-only in some releases;
      # install Google Chrome only when neither browser was preinstalled.
      apt-get update -qq
      apt-get install -y -qq --no-install-recommends ca-certificates curl gnupg
      curl -fsSL --retry 3 --connect-timeout 20 https://dl.google.com/linux/linux_signing_key.pub |
        gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
      printf '%s\n' 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main' \
        > /etc/apt/sources.list.d/google-chrome.list
      apt-get update -qq
      apt-get install -y -qq --no-install-recommends google-chrome-stable
      browser=google-chrome-stable; family=chrome
      ;;
    fedora)
      cat > /etc/yum.repos.d/google-chrome.repo <<'REPO'
[google-chrome]
name=Google Chrome - $basearch
baseurl=https://dl.google.com/linux/chrome/rpm/stable/$basearch
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
REPO
      dnf install -y google-chrome-stable
      browser=google-chrome-stable; family=chrome
      ;;
    arch) pacman -Sy --needed --noconfirm chromium; browser=chromium; family=chromium ;;
    alpine) apk add --no-cache chromium; browser=chromium; family=chromium ;;
    *) echo "Unsupported desktop distribution" >&2; exit 20 ;;
  esac
fi
command -v "$browser" >/dev/null 2>&1 || exit 21
browser_path="$(command -v "$browser")"
if [ "$family" = chromium ]; then
  policy_dir=/etc/chromium/policies/managed
  alt_policy=/etc/chromium-browser/policies/managed
else
  policy_dir=/etc/opt/chrome/policies/managed
  alt_policy=""
fi
mkdir -p "$policy_dir"
cat > "$policy_dir/wfs-required-extensions.json" <<'POLICY'
{
  "ExtensionInstallForcelist": [
    "hlkenndednhfkekhgcdicdfddnkalmdm;https://clients2.google.com/service/update2/crx",
    "fdpohaocaechififmbbbbbknoalclacl;https://clients2.google.com/service/update2/crx"
  ]
}
POLICY
chmod 644 "$policy_dir/wfs-required-extensions.json"
if [ -n "$alt_policy" ]; then
  mkdir -p "$alt_policy"
  cp "$policy_dir/wfs-required-extensions.json" "$alt_policy/wfs-required-extensions.json"
  chmod 644 "$alt_policy/wfs-required-extensions.json"
fi
if command -v python3 >/dev/null 2>&1; then
  python3 - "$policy_dir/wfs-required-extensions.json" <<'PY'
import json,sys
entries=json.load(open(sys.argv[1],encoding="utf-8"))["ExtensionInstallForcelist"]
ids=[e.split(";")[0] for e in entries]
assert ids == ["hlkenndednhfkekhgcdicdfddnkalmdm","fdpohaocaechififmbbbbbknoalclacl"]
assert all(e.endswith(";https://clients2.google.com/service/update2/crx") for e in entries)
PY
else
  grep -Fq hlkenndednhfkekhgcdicdfddnkalmdm "$policy_dir/wfs-required-extensions.json"
  grep -Fq fdpohaocaechififmbbbbbknoalclacl "$policy_dir/wfs-required-extensions.json"
fi
# The KDE image already provides its own Chromium icon: do not duplicate it.
if [ "$action" = installed ] && [ "$family" = chrome ]; then
  mkdir -p /usr/share/applications
  cat > /usr/share/applications/wfs-browser.desktop <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Chrome (WFS fallback)
Comment=Used only when the image has no preinstalled Chromium or Chrome
Exec=$browser_path %U
Terminal=false
Categories=Network;WebBrowser;
EOF
fi
printf '%s\n' "$family" > /etc/wfs-browser-family
printf '%s\n' "$browser_path" > /etc/wfs-browser-executable
printf '%s\n' "$action" > /etc/wfs-browser-install-action
"$browser" --version
echo "[WFS Browser] PASS: $family ($action), policy $policy_dir/wfs-required-extensions.json"
echo "[WFS Browser] Verify actual downloads after opening browser: chrome://policy and chrome://extensions"
IN_CONTAINER
family="$(docker exec wfs-linux-webtop cat /etc/wfs-browser-family)"
selected="$(docker exec wfs-linux-webtop cat /etc/wfs-browser-executable)"
action="$(docker exec wfs-linux-webtop cat /etc/wfs-browser-install-action)"
{
 echo WFS_CHROME_READY=1
 echo "WFS_BROWSER_FAMILY=$family"
 echo "WFS_BROWSER_EXE=$selected"
 echo "WFS_BROWSER_ACTION=$action"
} >> "$GITHUB_ENV"
echo "[WFS Browser] PASS: $family at $selected ($action); no duplicate Chrome install when Chromium is present."
