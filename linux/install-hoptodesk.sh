#!/usr/bin/env bash
set -Eeuo pipefail
name=wfs-linux-webtop
tmp="$RUNNER_TEMP/hoptodesk.AppImage"
url="https://dl.hoptodesk.com/hoptodesk.AppImage"
sha="747443d490ac3df49c62835dc9533021ec94a2b14311af1796cc972ba0c8a28a"

case "${WFS_DISTRO:-debian}" in
  debian|ubuntu|fedora|arch) ;;
  alpine)
    echo "::warning title=HopToDesk unsupported::The official AppImage requires glibc; Alpine uses musl."
    exit 1
    ;;
  *) echo "::error::Unsupported distro for HopToDesk."; exit 1 ;;
esac

curl -fL --retry 3 --connect-timeout 20 "$url" -o "$tmp"
echo "$sha  $tmp" | sha256sum -c -
docker cp "$tmp" "$name:/tmp/hoptodesk.AppImage"
docker exec -u 0 "$name" bash -lc '
  set -e
  chmod 0755 /tmp/hoptodesk.AppImage
  mkdir -p /opt/hoptodesk
  cd /opt/hoptodesk
  /tmp/hoptodesk.AppImage --appimage-extract >/dev/null
  test -x squashfs-root/AppRun
  rm -rf /opt/hoptodesk/current
  mv squashfs-root current
  cat > /usr/share/applications/hoptodesk.desktop <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=HopToDesk
Comment=Remote desktop client
Exec=/opt/hoptodesk/current/AppRun
Terminal=false
Categories=Network;RemoteAccess;
StartupNotify=true
EOF
  chmod 0644 /usr/share/applications/hoptodesk.desktop
  rm -f /tmp/hoptodesk.AppImage
  test -x /opt/hoptodesk/current/AppRun
'
echo "[HopToDesk] Official AppImage SHA-256 verified; desktop launcher installed."
