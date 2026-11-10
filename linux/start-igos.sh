#!/usr/bin/env bash
# Boot the genuine IGN 26 live ISO in a QEMU guest, shown inside the xrdp desktop.
# This is experimental on GitHub-hosted runners (typically without KVM).
# The outer container remains Ubuntu Webtop so RDP, Chrome and Tailscale remain safe.
set -Eeuo pipefail
say() { printf '[WFS IGOS 26 VM] %s\n' "$*"; }
die() { printf '::error::[WFS IGOS 26 VM] %s\n' "$*" >&2; exit 1; }
[ "${WFS_DISTRO:-}" = igos-nusantara ] || { say "Another distro selected; skipping IGN ISO."; exit 0; }
[ "${WFS_REMOTE:-}" = rdp ] || die "IGN 26 VM requires RDP mode (web access to the actual guest is not implemented)."
[ "${WFS_RDP_READY:-0}" = 1 ] || die "xrdp must pass its own authentication/handshake checks first."
docker inspect wfs-linux-webtop >/dev/null || die "Outer Webtop container is missing."
say "Preparing actual IGN 26 Ciremai Beta 6 live ISO (not Fedora/Ubuntu rebranded)."
docker exec -i -u 0 wfs-linux-webtop /bin/bash -s <<'IN_CONTAINER'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
  qemu-system-x86 ovmf tigervnc-viewer ca-certificates curl iproute2
iso=/var/tmp/wfs-ign26-bayu-beta6.iso
# Download directly from the official publisher. No unverified third-party mirror.
url=https://r2.igos-nusantara.or.id/iso/beta/ign26-bayu-beta6.iso
if [ ! -s "$iso" ]; then
  curl --fail --location --show-error --silent --retry 3 --retry-all-errors \
    --connect-timeout 30 --max-time 900 --max-filesize 1600000000 \
    "$url" --output "$iso.partial"
  mv "$iso.partial" "$iso"
fi
size=$(stat -c %s "$iso")
[ "$size" -gt 1000000000 ] && [ "$size" -lt 1600000000 ] || {
  echo "Unexpected IGN 26 ISO size; refusing to start." >&2; exit 21;
}
# Record reproducible provenance; upstream must publish a trusted digest before
# this can be treated as cryptographically pinned image verification.
sha256sum "$iso" | cut -d' ' -f1 > /config/wfs-igos-iso.sha256
code=
vars=
for dir in /usr/share/OVMF /usr/share/edk2/ovmf; do
  for suffix in 4M _4M ''; do
    test -f "$dir/OVMF_CODE${suffix}.fd" || continue
    test -f "$dir/OVMF_VARS${suffix}.fd" || continue
    code="$dir/OVMF_CODE${suffix}.fd"
    vars="$dir/OVMF_VARS${suffix}.fd"
    break 2
  done
done
test -n "$code" || { echo "UEFI OVMF code/vars pair is not installed" >&2; exit 22; }
cp "$vars" /config/wfs-igos-ovmf-vars.fd
chmod 600 /config/wfs-igos-ovmf-vars.fd
if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  cpu=( -accel kvm -cpu host )
  echo "KVM available: hardware acceleration enabled."
else
  cpu=( -accel tcg,thread=multi -cpu max )
  echo "::warning::KVM not available: using slow QEMU TCG emulation. IGN 26 needs AVX2."
fi
# VNC is intentionally unauthenticated ONLY inside the existing authenticated
# container and bound to its loopback. Never expose it to Docker ports/Tailscale.
nohup qemu-system-x86_64 \
  -machine q35 -m 4096 -smp 2 "${cpu[@]}" -nodefaults \
  -device virtio-vga -device qemu-xhci -device usb-tablet -device usb-kbd \
  -device ich9-ahci,id=ahci \
  -drive if=none,id=igncd,file="$iso",media=cdrom,readonly=on \
  -device ide-cd,drive=igncd,bus=ahci.0 \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -drive if=pflash,format=raw,readonly=on,file="$code" \
  -drive if=pflash,format=raw,file=/config/wfs-igos-ovmf-vars.fd \
  -boot order=d -display none -vnc 127.0.0.1:1 \
  > /config/wfs-igos-qemu.log 2>&1 < /dev/null &
qemu_pid=$!
echo "$qemu_pid" > /config/wfs-igos-qemu.pid
ready=no
for attempt in $(seq 1 45); do
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    tail -80 /config/wfs-igos-qemu.log >&2
    echo "IGN 26 QEMU process exited" >&2; exit 23
  fi
  if (echo > /dev/tcp/127.0.0.1/5901) >/dev/null 2>&1; then ready=yes; break; fi
  sleep 2
done
[ "$ready" = yes ] || { tail -80 /config/wfs-igos-qemu.log >&2; exit 24; }
# Launch the guest viewer automatically after the user's Xorg/Xfce RDP login.
# Closing the viewer reveals the outer Xfce desktop with mandatory Chrome.
cat > /usr/local/bin/wfs-igos-viewer <<'VIEWER'
#!/usr/bin/env bash
exec vncviewer -Shared -FullScreen -SecurityTypes None 127.0.0.1:1
VIEWER
chmod 755 /usr/local/bin/wfs-igos-viewer
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/wfs-igos-vm.desktop <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=IGOS Nusantara 26 (VM)
Comment=View official IGN 26 Ciremai live desktop inside local QEMU virtual machine
Exec=/usr/local/bin/wfs-igos-viewer
Terminal=false
OnlyShowIn=XFCE;
DESKTOP
command -v vncviewer >/dev/null
echo "PASS: official ISO downloaded; QEMU VNC frontend ready on 127.0.0.1:5901."
echo "NOTICE: the VM's BAYU graphical boot and guest applications are NOT yet verified."
IN_CONTAINER
{
  echo "WFS_IGOS_VM_STATUS=QEMU VNC running; actual guest desktop boot not verified"
  echo "WFS_IGOS_ISO=https://r2.igos-nusantara.or.id/iso/beta/ign26-bayu-beta6.iso"
} >> "$GITHUB_ENV"
say "IGN VM launched; open the native RDP desktop and the viewer starts automatically."
say "Chrome and required extensions live in the OUTER Ubuntu desktop, not inside the ISO guest."
