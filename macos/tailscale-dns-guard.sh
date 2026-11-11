#!/usr/bin/env bash
# Work around Tailscale GitHub Action macOS DNS override (tailscale/github-action#315).
# Preserve native GitHub runner DNS before the action; restore immediately after.
# Never edit DNS on a non-GitHub-hosted or non-macOS host.
set -Eeuo pipefail
umask 077

state="${RUNNER_TEMP:?}/wfs-macos"
file="$state/dns-ethernet.before"
service=Ethernet
say() { printf '[WFS macOS DNS] %s\n' "$*"; }
warn() { printf '::warning title=macOS DNS::%s\n' "$*"; }
guard() {
  [ "$(uname -s)" = Darwin ] || { echo "Only supported on macOS." >&2; exit 2; }
  [ "${GITHUB_ACTIONS:-}" = true ] && [ "${RUNNER_ENVIRONMENT:-}" = github-hosted ] ||
    { echo "Only supported on ephemeral GitHub-hosted runners." >&2; exit 3; }
  command -v networksetup >/dev/null || { echo "networksetup missing." >&2; exit 4; }
}
present() {
  networksetup -listallnetworkservices 2>/dev/null | grep -Fxq "$service"
}
backup() {
  mkdir -p "$state"
  chmod 700 "$state"
  if ! present; then
    printf 'UNAVAILABLE\n' > "$file"
    say "Ethernet network service absent; DNS backup not needed."
    return
  fi
  local response
  response="$(networksetup -getdnsservers "$service" 2>&1)" ||
    { printf 'UNAVAILABLE\n' > "$file"; warn "Could not inspect original DNS; refusing blind restoration."; return; }
  if [[ "$response" == There\ aren\'t\ any\ DNS\ Servers* ]]; then
    printf 'EMPTY\n' > "$file"
    say "Saved original Ethernet DNS mode: automatic/no explicit servers."
    return
  fi
  # Validate addresses before writing to disk; no arbitrary command evaluation.
  local addr count=0
  : > "$file"
  while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    [[ "$addr" =~ ^[0-9a-fA-F:.]+$ ]] ||
      { printf 'UNAVAILABLE\n' > "$file"; warn "Unexpected DNS value; refusing to restore unknown configuration."; return; }
    printf '%s\n' "$addr" >> "$file"
    count=$((count+1))
  done <<< "$response"
  [ "$count" -gt 0 ] || printf 'UNAVAILABLE\n' > "$file"
  say "Saved original Ethernet DNS configuration ($count numeric server(s)); values omitted from logs."
}
restore() {
  if [ ! -s "$file" ]; then
    warn "No valid pre-action DNS backup; cannot safely restore."
    return 0
  fi
  if ! present; then
    warn "Ethernet network service not present after Tailscale action."
    return 0
  fi
  local first addr
  IFS= read -r first < "$file"
  if [ "$first" = UNAVAILABLE ]; then
    warn "Original DNS unknown; refusing unsafe DNS changes."
    return 0
  fi
  if [ "$first" = EMPTY ]; then
    sudo networksetup -setdnsservers "$service" Empty ||
      { warn "Could not restore automatic Ethernet DNS."; return 1; }
  else
    local servers=()
    while IFS= read -r addr; do
      [ -n "$addr" ] || continue
      [[ "$addr" =~ ^[0-9a-fA-F:.]+$ ]] || { warn "Corrupted DNS backup."; return 1; }
      servers+=("$addr")
    done < "$file"
    [ "${#servers[@]}" -gt 0 ] || { warn "Original DNS servers missing."; return 1; }
    sudo networksetup -setdnsservers "$service" "${servers[@]}" ||
      { warn "Failed to restore original DNS configuration."; return 1; }
  fi
  say "Restored pre-action Ethernet DNS settings; Tailscale IP access does not require MagicDNS."
}
diagnose() {
  if command -v tailscale >/dev/null 2>&1; then
    tailscale version 2>&1 | head -n 2 || true
    local state
    state="$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("BackendState","UNKNOWN"))' 2>/dev/null || true)"
    say "Tailscale backend: ${state:-unavailable}."
  else
    warn "Tailscale CLI is not available."
  fi
  if ! /usr/bin/dscacheutil -q host -a name api.github.com >/dev/null 2>&1; then
    warn "api.github.com lookup returned a nonzero exit code."
  else
    say "Public DNS resolver check completed."
  fi
}
guard
case "${1:-}" in
  backup) backup ;;
  restore) restore ;;
  diagnose) diagnose ;;
  *) echo "Usage: $0 backup|restore|diagnose" >&2; exit 2 ;;
esac
