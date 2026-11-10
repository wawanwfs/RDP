#!/usr/bin/env bash
# xrdp starts the selected X11 desktop (KDE, Xfce, MATE, i3 or LXQt).
# Account names are case-sensitive. In particular, RDP is NOT rdp.
set -Eeuo pipefail
die() { printf '::error::[WFS xrdp] %s\n' "$*" >&2; exit 1; }
info() { printf '[WFS Linux xrdp] %s\n' "$*"; }
case "$WFS_REMOTE" in
  novnc) info "Browser-only mode; no xrdp needed."; exit 0 ;;
  rdp|both) ;;
  *) die "Unsupported RDP mode" ;;
esac
case "$WFS_DISTRO" in
  ubuntu|debian|fedora|alpine|igos-nusantara) ;;
  arch) die "Arch xrdp is not currently supported without AUR packages." ;;
  *) die "Unsupported distro for xrdp" ;;
esac
docker inspect wfs-linux-webtop >/dev/null || die "Webtop container missing"
info "Installing Xorg/xrdp, selected $WFS_DESKTOP desktop, and validating Linux account '$WFS_RDP_USERNAME'."
docker exec -i -u 0 wfs-linux-webtop /bin/sh -s -- "$WFS_DISTRO" "$WFS_RDP_USERNAME" "$WFS_DESKTOP" <<'IN_CONTAINER'
set -eu
distro="$1"
# IGN guest is a separate ISO VM; xrdp authenticates on the Ubuntu shell.
[ "$distro" = igos-nusantara ] && distro=ubuntu
username="$2"
desktop="$3"
export DEBIAN_FRONTEND=noninteractive
case "$distro" in
  debian|ubuntu)
    apt-get update -qq
    # Explicitly install WINDOW MANAGER + DESKTOP, not just xfce4-session.
    # LinuxServer Webtop images use --no-install-recommends; without xfwm4
    # and xfdesktop4, RDP can authenticate but display only black.
    apt-get install -y -qq --no-install-recommends \
      xrdp xorgxrdp xserver-xorg-core xauth x11-xserver-utils \
      xfce4-session xfce4-panel xfce4-settings xfdesktop4 xfwm4 \
      xfce4-appfinder xfce4-terminal thunar \
      dbus dbus-x11 dbus-user-session passwd pamtester
    ;;
  fedora)
    dnf install -y xrdp xorgxrdp xorg-x11-server-Xorg xorg-x11-xauth \
      xfce4-session xfce4-panel xfce4-settings xfdesktop xfwm4 \
      xfce4-terminal Thunar dbus-daemon shadow-utils pamtester
    ;;
  alpine)
    apk add --no-cache xrdp xorgxrdp xorg-server xauth \
      xfce4-session xfce4-panel xfce4-settings xfdesktop xfwm4 \
      xfce4-terminal thunar dbus dbus-x11 shadow pamtester
    ;;
esac
# xrdp cannot launch Wayland sessions. Install and validate an actual X11
# entry point for the selected desktop; never secretly show Xfce for KDE.
case "$desktop" in
  kde)
    case "$distro" in
      debian|ubuntu)
        if ! apt-get install -y -qq --no-install-recommends plasma-desktop plasma-session-x11 kwin-x11; then
          apt-get install -y -qq --no-install-recommends plasma-desktop plasma-workspace-x11 kwin-x11
        fi
        ;;
      fedora)
        dnf install -y plasma-workspace-x11 kwin-x11 plasma-desktop
        ;;
      *) echo "KDE native XRDP unsupported for distro $distro" >&2; exit 29 ;;
    esac
    command -v startplasma-x11 >/dev/null || { echo "Missing KDE X11 session (startplasma-x11)" >&2; exit 30; }
    ;;
  mate)
    case "$distro" in
      debian|ubuntu) apt-get install -y -qq --no-install-recommends mate-session-manager mate-panel marco caja ;;
      fedora) dnf install -y mate-session-manager mate-panel marco caja ;;
      alpine) apk add --no-cache mate-session-manager mate-panel marco caja ;;
    esac
    command -v mate-session >/dev/null || exit 31
    ;;
  i3)
    case "$distro" in
      debian|ubuntu) apt-get install -y -qq --no-install-recommends i3-wm i3status dmenu ;;
      fedora) dnf install -y i3 i3status dmenu ;;
      alpine) apk add --no-cache i3wm i3status dmenu ;;
    esac
    command -v i3 >/dev/null || exit 32
    ;;
  lxqt)
    [ "$distro" = ubuntu ] || { echo "LXQt xrdp requires Ubuntu Webtop" >&2; exit 33; }
    apt-get install -y -qq --no-install-recommends lxqt-session lxqt-panel openbox pcmanfm-qt
    command -v startlxqt >/dev/null || exit 34
    ;;
  xfce) ;;
  *) echo "Unsupported desktop session: $desktop" >&2; exit 35 ;;
esac
printf '%s\n' "$desktop" > /etc/wfs-rdp-desktop
for required in xrdp xrdp-sesman xfce4-session xfwm4 xfdesktop dbus-run-session Xorg; do
  command -v "$required" >/dev/null 2>&1 || {
    echo "Required Xfce/Xorg component is absent: $required" >&2; exit 20;
  }
done
if ! id "$username" >/dev/null 2>&1; then
  # useradd accepts case-sensitive uppercase Unix names, unlike adduser's
  # conservative NAME_REGEX. --badname is fallback for Debian/Ubuntu.
  if ! useradd -m -s /bin/sh "$username"; then
    if [ "$distro" = debian ] || [ "$distro" = ubuntu ]; then
      useradd --badname -m -s /bin/sh "$username"
    else
      echo "Could not create exact-case Linux user: $username" >&2
      exit 21
    fi
  fi
fi
getent passwd "$username" >/dev/null || { echo "Exact-case Linux account absent from NSS" >&2; exit 22; }
id "$username" >/dev/null || { echo "Exact-case Linux account cannot be resolved" >&2; exit 23; }
password="$(cat /run/secrets/rdp_password)"
test -n "$password" || { echo "RDP secret is empty" >&2; exit 24; }
printf '%s:%s\n' "$username" "$password" | chpasswd
unset password
test -f /etc/pam.d/xrdp-sesman || { echo "xrdp PAM service missing" >&2; exit 25; }
if ! { cat /run/secrets/rdp_password; printf '\n'; } |
  pamtester xrdp-sesman "$username" authenticate acct_mgmt >/dev/null 2>&1; then
  echo "PAM login failed for exact-case xrdp account, refusing premature READY" >&2
  exit 26
fi
home="$(getent passwd "$username" | cut -d: -f6)"
test -d "$home" || { echo "RDP home missing" >&2; exit 27; }

# Never use the default startwm.sh that can fall through to a different
# DE/Xsession, or xfce4-session without xfdesktop/xfwm4.
cat > /usr/local/bin/wfs-xrdp-xfce-session <<'SESSION'
#!/bin/sh
set -eu
unset DBUS_SESSION_BUS_ADDRESS SESSION_MANAGER WAYLAND_DISPLAY
export XDG_SESSION_TYPE=x11
export GTK_USE_PORTAL=0
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$HOME/.config" "$HOME/.cache"
exec >> "$HOME/.wfs-xrdp-session.log" 2>&1
printf '[WFS XRDP] Starting X11 session as %s on DISPLAY=%s\n' "$(id -un)" "${DISPLAY:-missing}"
[ -n "${DISPLAY:-}" ] || { echo "Xorg DISPLAY not provided by xrdp-sesman"; exit 41; }
desktop=$(cat /etc/wfs-rdp-desktop)
case "$desktop" in
  kde)
    export XDG_CURRENT_DESKTOP=KDE
    export DESKTOP_SESSION=plasma
    export QT_QPA_PLATFORM=xcb
    export KWIN_COMPOSE=N
    export XDG_RUNTIME_DIR="/tmp/wfs-xdg-runtime-$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    exec dbus-run-session -- startplasma-x11
    ;;
  mate)
    unset XDG_RUNTIME_DIR
    export XDG_CURRENT_DESKTOP=MATE DESKTOP_SESSION=mate
    exec dbus-run-session -- mate-session
    ;;
  i3)
    unset XDG_RUNTIME_DIR
    export XDG_CURRENT_DESKTOP=i3 DESKTOP_SESSION=i3
    exec dbus-run-session -- i3
    ;;
  lxqt)
    unset XDG_RUNTIME_DIR
    export XDG_CURRENT_DESKTOP=LXQt DESKTOP_SESSION=lxqt
    exec dbus-run-session -- startlxqt
    ;;
  xfce)
    unset XDG_RUNTIME_DIR
    export XDG_CURRENT_DESKTOP=XFCE DESKTOP_SESSION=xfce
    exec dbus-run-session -- xfce4-session
    ;;
esac
echo "Invalid desktop selection in /etc/wfs-rdp-desktop" >&2
exit 44
SESSION
chmod 755 /usr/local/bin/wfs-xrdp-xfce-session
cat > /etc/xrdp/startwm.sh <<'STARTWM'
#!/bin/sh
# Explicit desktop entry point for every xrdp user, no Xsession fallback.
exec /usr/local/bin/wfs-xrdp-xfce-session
STARTWM
chmod 755 /etc/xrdp/startwm.sh
# Optional user entry point for Xsession and manual inspection.
printf '%s\n' '#!/bin/sh' 'exec /usr/local/bin/wfs-xrdp-xfce-session' > "$home/.xsession"
chown "$username" "$home/.xsession"
chmod 700 "$home/.xsession"
mkdir -p /run/xrdp /var/log
if [ -f /etc/X11/Xwrapper.config ]; then
  printf '%s\n' 'allowed_users=anybody' 'needs_root_rights=auto' > /etc/X11/Xwrapper.config
fi
if command -v dbus-daemon >/dev/null 2>&1 && [ ! -S /run/dbus/system_bus_socket ]; then
  mkdir -p /run/dbus
  dbus-daemon --system --fork >/dev/null 2>&1 || true
fi
# Verify exact case and a complete install BEFORE opening the tailnet port.
test "$(id -un "$(id -u "$username")")" = "$username"
test -x /etc/xrdp/startwm.sh
test -x /usr/local/bin/wfs-xrdp-xfce-session
echo "[WFS Linux xrdp] PASS: selected $desktop X11 entry point + exact Unix account '$username', PAM, xfwm4, xfdesktop, DBus, Xorg and explicit Xfce entry point."
xrdp-sesman
xrdp
IN_CONTAINER
info "Checking xrdp protocol (TCP/X.224) on localhost 13389."
python3 - <<'PY'
import socket, time
req = bytes.fromhex("030000130ee000000000000100080003000000")
for n in range(30):
    try:
        with socket.create_connection(("127.0.0.1", 13389), timeout=3) as conn:
            conn.settimeout(5)
            conn.sendall(req)
            result=conn.recv(64)
        if len(result)>=11 and result[:2]==b"\x03\x00":
            print("PASS: xrdp TCP/X.224 negotiation.")
            break
    except OSError:
        pass
    time.sleep(2)
else:
    raise SystemExit("xrdp not responding; check xrdp-sesman.log and xrdp.log.")
PY
echo "WFS_RDP_READY=1" >> "$GITHUB_ENV"
echo "WFS_RDP_DESKTOP_READY=$WFS_DESKTOP" >> "$GITHUB_ENV"
info "Account and selected X11 desktop packages verified; live GUI login still requires client smoke testing."
