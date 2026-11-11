#!/usr/bin/env bash
# Apple-backed hosted macOS only. No Hackintosh, TCC bypass, SIP override, or public tunnel.
set -Eeuo pipefail
umask 077
state="$RUNNER_TEMP/wfs-macos"
say() { printf '[WFS macOS] %s\n' "$*"; }
warn() { printf '::warning title=WFS macOS::%s\n' "$*"; }
die() { printf '::error title=WFS macOS::%s\n' "$*" >&2; exit 1; }
save() { printf '%s=%s\n' "$1" "$2" >> "$GITHUB_ENV"; }
validate() {
  test "$(uname -s)" = Darwin || die "Requires authentic macOS runner."
  test "$GITHUB_ACTIONS" = true || die "GitHub Actions only."
  test "$RUNNER_ENVIRONMENT" = github-hosted || die "Refusing password changes on persistent hosts."
  case "$WFS_REMOTE" in ssh|vnc|both) ;; *) die "Invalid access method";; esac
  case "$WFS_DURATION" in 1|3|6) ;; *) die "Invalid duration";; esac
  case "$WFS_PASSWORD_MODE" in same_from_secret|random_each_run) ;; *) die "Invalid password mode";; esac
  case "$WFS_HOSTNAME_MODE" in same_each_run|unique_each_run) ;; *) die "Invalid hostname mode";; esac
  [[ "$WFS_HOSTNAME_BASE" =~ ^[a-z][a-z0-9-]{0,38}$ ]] || die "Invalid hostname."
}
prepare() {
  validate
  mkdir -p "$state"; chmod 700 "$state"
  export WFS_PASSWORD_STATE="$state"
  python3 - <<'PY'
import os,pathlib,hashlib,hmac
secret=os.environ["WFS_REMOTE_SECRET"]
assert len(secret.encode()) >= 12 and "\n" not in secret and "\r" not in secret, "RDP_PASSWORD must be 12+ bytes, no newlines"
mode=os.environ["WFS_PASSWORD_MODE"]
run=os.environ["GITHUB_RUN_ID"]
password=secret if mode=="same_from_secret" else hmac.new(secret.encode(),f"wfs-macos:{run}:remote".encode(),hashlib.sha256).hexdigest()[:24]
dest=pathlib.Path(os.environ["WFS_PASSWORD_STATE"])/"password"
dest.write_text(password,encoding="utf-8"); dest.chmod(0o600)
print("[WFS macOS] Credentials prepared without exposing plaintext in logs.")
PY
  local hostname="$WFS_HOSTNAME_BASE"
  if test "$WFS_HOSTNAME_MODE" = unique_each_run; then hostname="$hostname-$GITHUB_RUN_ID"; fi
  save WFS_MAC_HOSTNAME "$hostname"
  save WFS_MAC_USER "$(id -un)"
  say "macOS $(sw_vers -productVersion) / $(uname -m); user=$(id -un); tailnet name=$hostname."
}
tailnet() {
  command -v tailscale >/dev/null 2>&1 || die "Tailscale GitHub Action did not install CLI."
  local ip
  ip="$(tailscale ip -4 | head -n1)"
  [[ "$ip" =~ ^100\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "No tailnet IPv4."
  printf '%s\n' "$ip" > "$state/ip"
  save WFS_MAC_IP "$ip"
  say "Private Tailscale IP $ip"
}
password() {
  local p
  p="$(cat "$state/password")"
  sudo dscl . -passwd "/Users/$(id -un)" "$p" >/dev/null ||
    die "Could not set temporary password on ephemeral runner account."
  say "Ephemeral macOS login password configured (never logged)."
}
ssh_server() {
  local ip="$1" user="$(id -un)" conf="$state/sshd_config"
  if ! ifconfig | grep -Fq "inet $ip "; then
    warn "Tailscale IP is not on a macOS interface. Skipping SSH rather than binding public."
    save WFS_MAC_SSH_STATUS NO_TAILNET_INTERFACE
    return 0
  fi
  sudo ssh-keygen -A >/dev/null 2>&1 || true
  cat > "$conf" <<CONF
Port 2222
ListenAddress $ip
AddressFamily inet
HostKey /etc/ssh/ssh_host_ed25519_key
PidFile $state/sshd.pid
PasswordAuthentication yes
KbdInteractiveAuthentication no
PubkeyAuthentication no
PermitRootLogin no
PermitEmptyPasswords no
UsePAM yes
AllowUsers $user
MaxAuthTries 3
LoginGraceTime 30
MaxSessions 3
LogLevel VERBOSE
Subsystem sftp /usr/libexec/sftp-server
CONF
  sudo /usr/sbin/sshd -t -f "$conf" || die "SSH configuration failed."
  sudo /usr/sbin/sshd -f "$conf" -E "$state/sshd.log" || die "SSH daemon launch failed."
  local ready=no
  for i in 1 2 3 4 5 6 7 8; do
    if nc -G 2 -z "$ip" 2222 >/dev/null 2>&1; then ready=yes; break; fi
    sleep 2
  done
  if test "$ready" = yes; then
    save WFS_MAC_SSH_STATUS TCP_READY_LOGIN_NOT_TESTED
    say "SSH listener ready: $ip:2222 (only Tailnet IPv4)."
  else
    save WFS_MAC_SSH_STATUS NOT_READY
    warn "SSH did not become ready; see runner diagnostics."
  fi
}
screen_sharing() {
  local kick="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"
  local user="$(id -un)"
  local console="$(stat -f %Su /dev/console 2>/dev/null || true)"
  say "Console user=$console. Attempting supported Screen Sharing services."
  if test -x "$kick"; then
    sudo "$kick" -activate -configure -access -on \
      -configure -allowAccessFor -specifiedUsers -configure -users "$user" -access -on -privs -all \
      -restart -agent > "$state/ard.log" 2>&1 || warn "ARD configuration was refused."
  fi
  sudo launchctl enable system/com.apple.screensharing >/dev/null 2>&1 || true
  sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist >/dev/null 2>&1 || true
  sudo launchctl kickstart -k system/com.apple.screensharing >/dev/null 2>&1 || true
  local ready=no
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if nc -G 2 -z 127.0.0.1 5900 >/dev/null 2>&1; then ready=yes; break; fi
    sleep 3
  done
  if test "$ready" = yes; then
    save WFS_MAC_VNC_STATUS PORT_OPEN_GUI_CONTROL_UNVERIFIED
    say "Apple Screen Sharing 5900 listening. Control permissions/headless screen NOT validated."
  else
    save WFS_MAC_VNC_STATUS UNAVAILABLE
    warn "Screen Sharing did not open port 5900 on hosted runner."
  fi
  if test "$console" != "$user"; then
    warn "Active console is not the runner user; VNC may show login window or black screen."
  fi
}
setup() {
  validate
  test -s "$state/password" || die "Prepare step missing."
  tailnet
  password
  local ip; ip="$(cat "$state/ip")"
  if test "$WFS_REMOTE" = ssh || test "$WFS_REMOTE" = both; then ssh_server "$ip"; fi
  if test "$WFS_REMOTE" = vnc || test "$WFS_REMOTE" = both; then screen_sharing; fi
}
summary() {
  local ip user
  ip="$(cat "$state/ip")"; user="$(id -un)"
  {
    echo "## 🍎 WFS macOS Remote Workspace"
    echo
    echo "| Property | Value |"
    echo "|---|---|"
    echo "| macOS / CPU | $(sw_vers -productVersion) / $(uname -m) |"
    echo "| Tailscale hostname | $WFS_MAC_HOSTNAME |"
    echo "| Private Tailscale IP | $ip |"
    echo "| macOS login username | $user |"
    echo "| Login password | Existing GitHub secret RDP_PASSWORD; mode $WFS_PASSWORD_MODE (never printed) |"
    echo "| SSH :2222 | $WFS_MAC_SSH_STATUS |"
    echo "| Apple Screen Sharing :5900 | $WFS_MAC_VNC_STATUS |"
    echo "| Session duration | Selected $WFS_DURATION hour(s), total GitHub job cap 360 min including setup |"
    echo
    echo "**Windows PowerShell (SSH):** \`ssh -p 2222 $user@$ip\` (if SSH is listening)."
    echo
    echo "**Screen Sharing (VNC):** connect to \`$ip:5900\` from a VNC viewer on the same tailnet; use macOS username \`$user\` and login password, if Apple's server accepts the authentication mechanism."
    echo
    echo "> [!WARNING]"
    echo "> Screen Sharing listener does **not** prove interactive GUI. On GitHub-hosted macOS, graphical login may be absent and Apple limits command-line enablement to view-only. Do not use mstsc/RDP; this is macOS VNC/SSH. For reliable fully interactive GUI use an approved Apple-backed self-hosted or managed Mac."
    echo
    echo "> **Security:** no SIP/TCC bypass, no public port forwarding, no credentials in Actions logs. GitHub-hosted instance and its files disappear after run."
  } >> "$GITHUB_STEP_SUMMARY"
  say "Summary written; no passwords displayed."
}
keepalive() {
  local seconds=$((WFS_DURATION * 3600))
  if (( seconds > 20500 )); then seconds=20500; fi
  local until_ts=$(( $(date +%s) + seconds ))
  caffeinate -dimsu &
  local coffee=$!
  trap 'kill "$coffee" >/dev/null 2>&1 || true' EXIT
  local count=0
  say "Remote session heartbeat active (up to $seconds seconds, capped by 360-minute GitHub job)."
  while (( $(date +%s) < until_ts )); do
    count=$((count+1))
    if (( count % 5 == 1 )); then
      say "Alive; remaining $(( (until_ts-$(date +%s))/60 )) min. GUI status=$WFS_MAC_VNC_STATUS."
    fi
    sleep 60
  done
}
cleanup() {
  if test -s "$state/sshd.pid"; then sudo kill "$(cat "$state/sshd.pid")" >/dev/null 2>&1 || true; fi
  rm -rf "$state" >/dev/null 2>&1 || true
  say "Temporary state removed."
}
case "$1" in
  validate) validate ;; prepare) prepare ;; setup) setup ;;
  summary) summary ;; keepalive) keepalive ;; cleanup) cleanup ;;
  *) die "Usage: workspace.sh validate|prepare|setup|summary|keepalive|cleanup" ;;
esac
