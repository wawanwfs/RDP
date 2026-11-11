#!/usr/bin/env bash
# Apple-backed hosted macOS only. No Hackintosh, TCC bypass, SIP override, or public tunnel.
set -Eeuo pipefail
umask 077
state="$RUNNER_TEMP/wfs-macos"
say() { printf '[WFS macOS] %s\n' "$*"; }
warn() { printf '::warning title=WFS macOS::%s\n' "$*"; }
die() { printf '::error title=WFS macOS::%s\n' "$*" >&2; exit 1; }
save() {
  # GITHUB_ENV is consumed only by *subsequent* GitHub Actions steps.
  # Immediately update the current shell too, otherwise setup() still sees
  # WFS_MAC_SSH_STATUS=SKIPPED after ssh_server() successfully starts.
  local key="$1" value="$2"
  [[ "$key" =~ ^WFS_MAC_[A-Z0-9_]+$ ]] || die "Invalid internal status key."
  printf '%s=%s\n' "$key" "$value" >> "$GITHUB_ENV"
  printf -v "$key" '%s' "$value"
  export "$key"
}
validate() {
  test "$(uname -s)" = Darwin || die "Requires authentic macOS runner."
  test "$GITHUB_ACTIONS" = true || die "GitHub Actions only."
  test "$RUNNER_ENVIRONMENT" = github-hosted || die "Refusing password changes on persistent hosts."
  case "$WFS_REMOTE" in ssh|vnc|both) ;; *) die "Invalid access method";; esac
  case "$WFS_DURATION" in 1|3|6) ;; *) die "Invalid duration";; esac
  case "$WFS_PASSWORD_MODE" in same_from_secret|random_each_run) ;; *) die "Invalid password mode";; esac
  case "$WFS_HOSTNAME_MODE" in same_each_run|unique_each_run) ;; *) die "Invalid hostname mode";; esac
  [[ "$WFS_HOSTNAME_BASE" =~ ^[a-z][a-z0-9-]{0,38}$ ]] || die "Invalid hostname."
  [[ "$WFS_MAC_USER" =~ ^[a-z][a-z0-9_-]{1,20}$ ]] || die "Invalid remote macOS username."
  case "$WFS_MAC_USER" in runner|root|daemon|nobody|admin) die "Reserved macOS username";; esac
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
  save WFS_MAC_USER "$WFS_MAC_USER"
  say "macOS $(sw_vers -productVersion) / $(uname -m); remote user=$WFS_MAC_USER; runner user=$(id -un); tailnet name=$hostname."
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
create_account() {
  local p user="$WFS_MAC_USER"
  p="$(cat "$state/password")"
  if id "$user" >/dev/null 2>&1; then
    test -f "$state/account-created" || die "Refusing to modify a pre-existing macOS account."
    say "Ephemeral $user account already created for this workflow."
    return
  fi
  # A GitHub-hosted macOS runner may reject resetting the password of its
  # pre-existing SecureToken-protected 'runner' account. Create a separate,
  # standard, non-admin account instead; do not bypass SecureToken or TCC.
  if ! sudo sysadminctl -addUser "$user" -fullName "WFS Remote Workspace" -password "$p" > "$state/account.log" 2>&1; then
    warn "macOS rejected standard temporary-account creation; see sanitized diagnostics."
    tail -n 12 "$state/account.log" | sed -E 's/[Pp]assword=[^ ]+/password=[REDACTED]/g' || true
    die "Cannot create isolated WFS macOS remote account."
  fi
  id "$user" >/dev/null 2>&1 || die "macOS account creation returned success but user was not found."
  # macOS may restrict Remote Login through this local access group.
  sudo dseditgroup -o edit -a "$user" -t user com.apple.access_ssh >/dev/null 2>&1 ||
    warn "Cannot add temporary user to Remote Login access group."
  if dscl . -authonly "$user" "$p" >/dev/null 2>&1; then
    say "Local Directory Services password authentication verified for $user."
  else
    warn "New macOS account password not authenticated by Directory Services; SSH login may be rejected."
  fi
  touch "$state/account-created"
  say "Created separate non-admin macOS account $user, without changing runner password."
}
ssh_server() {
  local ip="$1" user="$WFS_MAC_USER" conf="$state/sshd_config"
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
  local user="$WFS_MAC_USER"
  local console="$(stat -f %Su /dev/console 2>/dev/null || true)"
  say "Console user=$console. Attempting supported Screen Sharing services."
  # Configure ARD in discrete, documented commands. A single invocation
  # containing multiple -configure blocks can silently skip per-user rights.
  # Only our disposable, non-admin account is eligible; never allow all users.
  local ardstatus="NOT_CONFIGURED" attr
  if test -x "$kick"; then
    : > "$state/ard.log"
    if ! sudo "$kick" -activate -configure -access -on >> "$state/ard.log" 2>&1; then
      warn "Remote Management activation returned an error (see Actions diagnostics)."
    fi
    if ! sudo "$kick" -configure -allowAccessFor -specifiedUsers >> "$state/ard.log" 2>&1; then
      warn "Failed to restrict Remote Management to explicitly specified users."
      ardstatus="ACCESS_LIST_FAILED"
    elif ! sudo "$kick" -configure -users "$user" -access -on -privs -all >> "$state/ard.log" 2>&1; then
      warn "Could not grant Remote Management Observe/Control rights to $user."
      ardstatus="USER_GRANT_FAILED"
    else
      ardstatus="USER_GRANT_COMMAND_SUCCEEDED"
    fi
    # This access group alone is not sufficient but can be required depending
    # on the Mac's Screen Sharing configuration. Never add the admin group.
    if dscl . -read /Groups/com.apple.access_screensharing >/dev/null 2>&1; then
      sudo dseditgroup -o edit -a "$user" -t user com.apple.access_screensharing >> "$state/ard.log" 2>&1 ||
        warn "Screen Sharing access group could not be updated."
    fi
    sudo "$kick" -restart -agent >> "$state/ard.log" 2>&1 ||
      warn "ARD agent restart did not finish cleanly."
    if attr="$(dscl . -read "/Users/$user" dsAttrTypeNative:naprivs 2>/dev/null)"; then
      say "ARD per-user privileges attribute exists for $user (not proof of authenticated VNC control)."
      if test "$ardstatus" = USER_GRANT_COMMAND_SUCCEEDED; then
        ardstatus="USER_GRANT_ATTRIBUTE_PRESENT_GUI_UNVERIFIED"
      fi
    else
      warn "No ARD per-user privilege attribute found for $user. SSH rights do not grant VNC rights."
      if test "$ardstatus" = USER_GRANT_COMMAND_SUCCEEDED; then
        ardstatus="USER_PRIVILEGES_UNVERIFIED"
      fi
    fi
  else
    warn "Apple ARD kickstart is not available."
  fi
  save WFS_MAC_ARD_STATUS "$ardstatus"
  sudo launchctl enable system/com.apple.screensharing >/dev/null 2>&1 || true
  sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist >/dev/null 2>&1 || true
  sudo launchctl kickstart -k system/com.apple.screensharing >/dev/null 2>&1 || true
  local ready=no
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if nc -G 2 -z 127.0.0.1 5900 >/dev/null 2>&1; then ready=yes; break; fi
    sleep 3
  done
  if test "$ready" = yes; then
    # A TCP listener is not necessarily an RFB server, and even a valid RFB
    # banner says nothing about an accessible or controllable GUI.
    if python3 - <<'PY'
import socket,sys
try:
    with socket.create_connection(("127.0.0.1",5900),timeout=3) as conn:
        conn.settimeout(3)
        greeting=conn.recv(12)
    if not greeting.startswith(b"RFB "):
        raise ValueError("Not an RFB endpoint")
except (OSError,ValueError):
    sys.exit(1)
PY
    then
      save WFS_MAC_VNC_STATUS RFB_READY_GUI_CONTROL_UNVERIFIED
      say "Apple Screen Sharing returned an RFB protocol banner; graphical control still unverified."
    else
      save WFS_MAC_VNC_STATUS PORT_OPEN_NO_RFB
      warn "TCP 5900 responds but no VNC/RFB header was received."
    fi
  else
    save WFS_MAC_VNC_STATUS UNAVAILABLE
    warn "Screen Sharing did not open port 5900. Apple may block scripted activation on recent macOS."
  fi
  if test "$console" != "$user"; then
    warn "Console belongs to $console, not isolated remote user $user; ARD may reject this account or display a different session."
  fi
  say "VNC RFB listener does not establish authentication; macOS 12.1+ may require GUI/MDM approval for full control."
}
check_remote_ready() {
  # Stop immediately instead of charging hours for an unavailable endpoint.
  # In 'both' mode, SSH remains usable even when Apple Screen Sharing fails.
  case "$WFS_REMOTE" in
    ssh)
      test "$WFS_MAC_SSH_STATUS" = TCP_READY_LOGIN_NOT_TESTED ||
        die "SSH unavailable on private Tailnet; ending without Keep Alive."
      ;;
    vnc)
      test "$WFS_MAC_VNC_STATUS" = RFB_READY_GUI_CONTROL_UNVERIFIED ||
        die "VNC-only mode unavailable; Apple Screen Sharing did not return RFB. Try both/ssh instead of wasting runner hours."
      ;;
    both)
      test "$WFS_MAC_SSH_STATUS" = TCP_READY_LOGIN_NOT_TESTED ||
        die "Private SSH unavailable; VNC alone is not a verified login path."
      if test "$WFS_MAC_VNC_STATUS" != RFB_READY_GUI_CONTROL_UNVERIFIED; then
        warn "VNC is not available; SSH is usable via private Tailscale IP."
      fi
      ;;
  esac
}
status_smoke() {
  # Regression for GitHub Actions env propagation: GITHUB_ENV updates do
  # not affect the current Bash process without save() also exporting values.
  validate
  local result_file="$RUNNER_TEMP/wfs-macos-status-smoke.env"
  local prior_env="$GITHUB_ENV" prior_mode="$WFS_REMOTE"
  export GITHUB_ENV="$result_file"
  : > "$GITHUB_ENV"
  export WFS_REMOTE=both
  export WFS_MAC_SSH_STATUS=SKIPPED
  export WFS_MAC_VNC_STATUS=SKIPPED
  save WFS_MAC_SSH_STATUS TCP_READY_LOGIN_NOT_TESTED
  save WFS_MAC_VNC_STATUS RFB_READY_GUI_CONTROL_UNVERIFIED
  test "$WFS_MAC_SSH_STATUS" = TCP_READY_LOGIN_NOT_TESTED ||
    die "Regression: status update didn't reach current Bash process"
  test "$WFS_MAC_VNC_STATUS" = RFB_READY_GUI_CONTROL_UNVERIFIED ||
    die "Regression: VNC status update didn't reach current Bash process"
  grep -Fxq 'WFS_MAC_SSH_STATUS=TCP_READY_LOGIN_NOT_TESTED' "$GITHUB_ENV"
  grep -Fxq 'WFS_MAC_VNC_STATUS=RFB_READY_GUI_CONTROL_UNVERIFIED' "$GITHUB_ENV"
  check_remote_ready
  say "PASS: same-process status and GITHUB_ENV updated; both-mode check succeeds."
  export GITHUB_ENV="$prior_env" WFS_REMOTE="$prior_mode"
  rm -f "$result_file"
}
setup() {
  validate
  test -s "$state/password" || die "Prepare step missing."
  tailnet
  create_account
  local ip; ip="$(cat "$state/ip")"
  if test "$WFS_REMOTE" = ssh || test "$WFS_REMOTE" = both; then ssh_server "$ip"; fi
  if test "$WFS_REMOTE" = vnc || test "$WFS_REMOTE" = both; then screen_sharing; fi
  check_remote_ready

}
local_smoke() {
  validate
  test -s "$state/password" || die "Prepare synthetic CI credentials first."
  test "$WFS_REMOTE" = ssh || die "Local SSH smoke must use remote_access=ssh."
  # Never join Tailscale or open an externally reachable socket in this test.
  create_account
  ssh_server 127.0.0.1
  test "$(nc -G 2 -z 127.0.0.1 2222 >/dev/null 2>&1; echo $?)" = 0 ||
    die "Localhost SSH listener failed."
  local askpass="$state/ssh-askpass" known="$state/known_hosts" user="$WFS_MAC_USER"
  cat > "$askpass" <<ASKPASS
#!/bin/sh
cat "$state/password"
ASKPASS
  chmod 700 "$askpass"
  # SSH_ASKPASS_REQUIRE=force lets OpenSSH authenticate non-interactively
  # without printing a password or requiring an interactive GitHub job TTY.
  local identity
  if ! identity="$(SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
    ssh -o ConnectionAttempts=1 -o ConnectTimeout=10 \
      -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$known" \
      -o PreferredAuthentications=password -o PubkeyAuthentication=no \
      -o BatchMode=no -p 2222 "$user@127.0.0.1" 'id -un' </dev/null 2>"$state/ssh-client.log")"; then
    warn "SSH password login did not succeed; showing client/server errors (never password)."
    tail -n 15 "$state/ssh-client.log" || true
    sudo tail -n 25 "$state/sshd.log" || true
    die "SSH password authentication smoke failed."
  fi
  test "$identity" = "$user" || die "SSH authenticated as unexpected user."
  say "PASS: macOS local SSH authenticated using temporary password, 127.0.0.1:2222."
}
summary() {
  local ip user
  ip="$(cat "$state/ip")"; user="$WFS_MAC_USER"
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
    echo "| Apple Screen Sharing :5900 | $WFS_MAC_VNC_STATUS (RFB listener only; GUI not confirmed) |"
    echo "| Remote Management user grant | ${WFS_MAC_ARD_STATUS:-NOT_CHECKED} (permission ≠ successful VNC login) |"
    echo "| Console session user | $(stat -f %Su /dev/console 2>/dev/null || echo unavailable) (may differ from VNC login user) |"
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
  if test -s "$state/sshd.pid"; then
    pid="$(sudo cat "$state/sshd.pid" 2>/dev/null || true)"
    if [[ "$pid" =~ ^[0-9]+$ ]]; then sudo kill "$pid" >/dev/null 2>&1 || true; fi
  fi
  if test "$state" = "$RUNNER_TEMP/wfs-macos"; then
    sudo rm -rf "$state" >/dev/null 2>&1 || true
  fi
  say "Temporary state removed."
}
case "$1" in
  validate) validate ;; prepare) prepare ;; setup) setup ;; local-smoke) local_smoke ;; status-smoke) status_smoke ;;
  summary) summary ;; keepalive) keepalive ;; cleanup) cleanup ;;
  *) die "Usage: workspace.sh validate|prepare|setup|summary|keepalive|cleanup" ;;
esac
