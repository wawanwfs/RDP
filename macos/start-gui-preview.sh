#!/usr/bin/env bash
# Run read-only screenshot mirror under remote account, bound to private Tailnet.
set -Eeuo pipefail
state="$RUNNER_TEMP/wfs-macos"
user="$WFS_MAC_USER"
ip="$WFS_MAC_IP"
test "$RUNNER_ENVIRONMENT" = github-hosted
test "$GITHUB_ACTIONS" = true
[[ "$user" =~ ^[a-z][a-z0-9_-]{1,20}$ ]] || exit 2
test -s "$state/password"
test -s "$state/ip"
test "$ip" = "$(cat "$state/ip")"
id "$user" >/dev/null 2>&1
home="$(dscl . -read "/Users/$user" NFSHomeDirectory | awk '{print $2}')"
test -n "$home" && test -d "$home"
profile="$home/.wfs-preview"
sudo mkdir -p "$profile"
sudo chown "$user" "$profile"
sudo chmod 700 "$profile"
sudo cp "$state/password" "$profile/login-secret"
sudo chown "$user" "$profile/login-secret"
sudo chmod 600 "$profile/login-secret"
log="$state/gui-preview.log"
: > "$log"
echo "[WFS Preview] Launching private read-only screenshot mirror as $user."
sudo -H -u "$user" /usr/bin/python3 "$GITHUB_WORKSPACE/macos/gui-preview.py" \
  --host "$ip" --port 6081 --username "$user" --password-file "$profile/login-secret" \
  > "$log" 2>&1 &
pid="$!"
printf '%s\n' "$pid" > "$state/gui-preview.pid"
ready=no
for i in 1 2 3 4 5 6 7 8 9 10; do
  if nc -G 2 -z "$ip" 6081 >/dev/null 2>&1; then ready=yes; break; fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 2
done
if test "$ready" = yes; then
  echo 'WFS_MAC_PREVIEW_STATUS=LISTENER_READY_FRAME_UNVERIFIED' >> "$GITHUB_ENV"
  echo "[WFS Preview] Private listener on http://$ip:6081. Username $user; password from RDP_PASSWORD secret."
  echo "[WFS Preview] This preview is READ-ONLY. Test actual frame from browser."
else
  echo 'WFS_MAC_PREVIEW_STATUS=UNAVAILABLE' >> "$GITHUB_ENV"
  echo "::warning title=macOS GUI Preview::Private screenshot listener unavailable; SSH and VNC are not changed."
  if test -s "$log"; then tail -n 10 "$log" | sed -E 's/password[^ ]*/[REDACTED]/g'; fi
fi
