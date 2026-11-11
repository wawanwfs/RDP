#!/usr/bin/env bash
# Optional macOS native applications — never claim successful installation without proof.
set -Eeuo pipefail
state="$RUNNER_TEMP/wfs-macos"
mkdir -p "$state"
status="$state/apps.tsv"
: > "$status"
record() { printf '%s\t%s\n' "$1" "$2" >> "$status"; echo "[WFS macOS Apps] $1: $2"; }
check_app() { test -d "$1" || test -x "$1"; }
say() { echo "[WFS macOS Apps] $*"; }
case "$WFS_IDE" in
  vscode)
    if check_app "/Applications/Visual Studio Code.app"; then
      record "Visual Studio Code" "PRESENT (existing app bundle)"
    elif command -v brew >/dev/null 2>&1 && brew install --cask visual-studio-code; then
      if check_app "/Applications/Visual Studio Code.app"; then record "Visual Studio Code" "INSTALLED"; else record "Visual Studio Code" "UNVERIFIED"; fi
    else record "Visual Studio Code" "FAILED (brew installer)"; fi
    ;;
  none) record "Visual Studio Code" "SKIPPED" ;;
  *) record "Visual Studio Code" "UNSUPPORTED_SELECTION";;
esac

# Safari is provided by macOS; Chrome may be preloaded on Actions. No duplicate
# downloads merely to make Chrome the default browser.
if check_app "/Applications/Safari.app" || check_app "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"; then
  record "Safari" "AVAILABLE (system browser; extensions not preconfigured)"
else
  record "Safari" "CHECK_REQUIRED (system app path not detected)"
fi
if check_app "/Applications/Google Chrome.app"; then
  record "Google Chrome" "AVAILABLE (bundled; no duplicate installation)"
fi

case "$WFS_AGENT" in
  codex|claude|both)
    if ! command -v npm >/dev/null 2>&1; then
      record "AI CLIs" "FAILED (npm missing)"
    else
      if test "$WFS_AGENT" = codex || test "$WFS_AGENT" = both; then
        if command -v codex >/dev/null 2>&1 || npm install -g --no-audit --no-fund @openai/codex; then
          if command -v codex >/dev/null 2>&1; then record "Codex CLI" "INSTALLED (provider login not configured)"; else record "Codex CLI" "UNVERIFIED"; fi
        else record "Codex CLI" "FAILED"; fi
      fi
      if test "$WFS_AGENT" = claude || test "$WFS_AGENT" = both; then
        if command -v claude >/dev/null 2>&1 || npm install -g --no-audit --no-fund @anthropic-ai/claude-code; then
          if command -v claude >/dev/null 2>&1; then record "Claude Code" "INSTALLED (provider login not configured)"; else record "Claude Code" "UNVERIFIED"; fi
        else record "Claude Code" "FAILED"; fi
      fi
    fi
    ;;
esac

if test "$WFS_TRADING" = webterminal; then
  record "MetaTrader WebTerminal" "BROWSER_ONLY (https://web.metatrader.app/; does not run desktop EAs)"
else
  record "MetaTrader" "NOT_SELECTED (native macOS MT4/MT5 is not provided)"
fi
if test "$WFS_APPS" = developer || test "$WFS_APPS" = all; then
  for tool in git python3 clang swift xcodebuild; do
    if command -v "$tool" >/dev/null 2>&1; then
      record "Toolchain $tool" "AVAILABLE"
    else
      record "Toolchain $tool" "NOT_FOUND"
    fi
  done
fi
if test "$WFS_APPS" = media || test "$WFS_APPS" = all; then
  if command -v ffmpeg >/dev/null 2>&1; then record ffmpeg "AVAILABLE"; else record ffmpeg "NOT_INSTALLED"; fi
fi
if test -n "$GITHUB_STEP_SUMMARY"; then
  {
    echo "### Optional macOS Applications"
    echo
    echo "| Application | Status |"
    echo "|---|---|"
    while IFS="$(printf '\t')" read -r name result; do
      echo "| $name | $result |"
    done < "$status"
  } >> "$GITHUB_STEP_SUMMARY"
fi
say "Optional apps checked; provider logins and app GUI windows are not tested."
