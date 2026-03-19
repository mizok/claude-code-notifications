#!/bin/bash
# Claude Code Auto-Update Installer
# Usage:
#   ./install.sh            — interactive install
#   ./install.sh --now      — run update check immediately (no schedule)
#   ./install.sh --status   — show status + recent log
#   ./install.sh --uninstall — remove everything

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
LABEL="com.claude-code.autoupdate"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="$HOME/.local/bin/claude-code-updater"
LOG="$HOME/.claude/autoupdate.log"
ERR_LOG="$HOME/.claude/autoupdate-error.log"
LOCKDIR="$HOME/.claude/autoupdate.lock"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BOLD}→ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✗ $*${RESET}" >&2; }
die()     { error "$*"; exit 1; }

# ── Preflight checks ─────────────────────────────────────────────────────────
preflight() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This script only works on macOS."
  [[ "$(id -u)" -ne 0 ]] || die "Do not run as root."
  command -v brew >/dev/null 2>&1 || die "Homebrew not found. Install from https://brew.sh first."
  brew list --cask claude-code >/dev/null 2>&1 \
    || die "Claude Code is not installed via Homebrew Cask.\nRun: brew install --cask claude-code"
}

# ── Write the updater script ──────────────────────────────────────────────────
write_updater_script() {
  mkdir -p "$(dirname "$SCRIPT")"
  cat > "$SCRIPT" << 'UPDATER'
#!/bin/bash
# Claude Code Auto-Updater

LOG="$HOME/.claude/autoupdate.log"
LOCKDIR="$HOME/.claude/autoupdate.lock"

ts() { date "+%Y-%m-%d %H:%M:%S"; }

# Locate Homebrew using absolute paths (launchd has minimal PATH)
BREW_BIN=""
for _b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$_b" ]; then BREW_BIN="$_b"; break; fi
done
if [ -z "$BREW_BIN" ]; then
  echo "[$(ts)] ERROR: Cannot find brew binary. Checked /opt/homebrew and /usr/local." >> "$LOG"
  exit 1
fi
BREW_PREFIX="$($BREW_BIN --prefix 2>/dev/null)"
export PATH="$BREW_PREFIX/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Prevent overlapping runs
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "[$(ts)] Skipping — another instance is already running" >> "$LOG"
  exit 0
fi
trap 'rm -rf "$LOCKDIR"' EXIT INT TERM

echo "[$(ts)] Checking for Claude Code updates..." >> "$LOG"

# Refresh Homebrew index
if ! $BREW_BIN update --quiet 2>> "$LOG"; then
  echo "[$(ts)] WARNING: brew update failed, continuing with cached index" >> "$LOG"
fi

# Check if outdated (--greedy handles casks with auto_updates true)
OUTDATED=$($BREW_BIN outdated --cask --greedy 2>/dev/null | grep "^claude-code" || true)

if [ -z "$OUTDATED" ]; then
  CURRENT=$($BREW_BIN list --cask --versions claude-code 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
  echo "[$(ts)] Up-to-date: $CURRENT" >> "$LOG"
  exit 0
fi

# Parse versions for display only — non-critical
CURRENT=$(echo "$OUTDATED" | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\)' \
  | tr -d '()' | head -1 || echo "unknown")
LATEST=$(echo "$OUTDATED" | awk '{print $NF}' | head -1 || echo "unknown")

echo "[$(ts)] Update available: $CURRENT → $LATEST" >> "$LOG"
$BREW_BIN upgrade --cask --greedy claude-code >> "$LOG" 2>&1

if [ $? -eq 0 ]; then
  echo "[$(ts)] Successfully updated to $LATEST" >> "$LOG"
  # Desktop notification (requires claude-code-notifications skill)
  if command -v grrr &>/dev/null; then
    grrr --appId Claude-Code --title "Claude Code Updated" \
      "Updated $CURRENT → $LATEST" 2>/dev/null || true
  fi
else
  echo "[$(ts)] Update FAILED — see log for details" >> "$LOG"
  exit 1
fi
UPDATER

  chmod +x "$SCRIPT"
}

# ── Write the LaunchAgent plist ───────────────────────────────────────────────
write_plist() {
  local hour=$1 minute=$2
  mkdir -p "$(dirname "$PLIST")"
  cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>Program</key>
  <string>$SCRIPT</string>
  <key>ProgramArguments</key>
  <array>
    <string>claude-code-updater</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$hour</integer>
    <key>Minute</key>
    <integer>$minute</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$ERR_LOG</string>
</dict>
</plist>
EOF
}

# ── launchd helpers ───────────────────────────────────────────────────────────
agent_registered() {
  launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1
}

bootstrap_agent() {
  plutil -lint "$PLIST" >/dev/null 2>&1 || die "Plist syntax error: $PLIST"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
}

bootout_agent() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
}

# ── Commands ──────────────────────────────────────────────────────────────────
cmd_install() {
  preflight

  echo ""
  echo -e "${BOLD}Claude Code Auto-Update Setup${RESET}"
  echo "────────────────────────────────"

  # Warn if claude binary is not from Homebrew
  local claude_path brew_prefix
  claude_path=$(command -v claude 2>/dev/null || true)
  brew_prefix=$(brew --prefix 2>/dev/null || true)
  if [[ -n "$claude_path" && -n "$brew_prefix" ]] \
      && [[ "$claude_path" != "$brew_prefix"* ]]; then
    warn "Active 'claude' ($claude_path) is not under Homebrew prefix."
    warn "The cask will be updated correctly, but your PATH may still resolve the old binary."
    echo ""
  fi

  # Ask for time
  local time_input hour minute
  read -rp "$(echo -e "Daily update time ${BOLD}[HH:MM, default 09:00]${RESET}: ")" time_input
  time_input="${time_input:-09:00}"

  if ! [[ "$time_input" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
    die "Invalid time format. Use HH:MM (e.g. 09:00)"
  fi
  hour="${BASH_REMATCH[1]#0}"   # strip leading zero to avoid octal
  minute="${BASH_REMATCH[2]#0}"
  hour="${hour:-0}"
  minute="${minute:-0}"

  [[ "$hour" -ge 0 && "$hour" -le 23 ]] || die "Hour must be 0–23."
  [[ "$minute" -ge 0 && "$minute" -le 59 ]] || die "Minute must be 0–59."

  # Create dirs
  info "Creating directories..."
  mkdir -p "$HOME/.claude" "$HOME/.local/bin" "$HOME/Library/LaunchAgents"
  success "Directories ready"

  # Write updater script
  info "Writing updater script to $SCRIPT..."
  write_updater_script
  success "Updater script created"

  # Write plist
  info "Writing LaunchAgent plist..."
  write_plist "$hour" "$minute"
  success "Plist created"

  # Bootstrap
  info "Registering LaunchAgent..."
  bootstrap_agent
  success "LaunchAgent registered"

  # Verify
  if agent_registered; then
    success "Verified: LaunchAgent is active"
  else
    die "LaunchAgent registration failed. Check $PLIST"
  fi

  local display_hour display_minute
  display_hour=$(printf "%02d" "$hour")
  display_minute=$(printf "%02d" "$minute")

  echo ""
  echo -e "${GREEN}${BOLD}Done!${RESET}"
  echo -e "Claude Code will be checked for updates every day at ${BOLD}${display_hour}:${display_minute}${RESET}."
  echo -e "Logs: ${BOLD}$LOG${RESET}"
  echo ""
  echo -e "Run ${BOLD}$(basename "$0") --now${RESET} to trigger an immediate check."
}

cmd_status() {
  echo ""
  echo -e "${BOLD}Claude Code Auto-Update Status${RESET}"
  echo "────────────────────────────────"

  if agent_registered; then
    local state
    state=$(launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null \
      | grep -E 'state|last exit' || true)
    success "LaunchAgent registered"
    echo "$state" | sed 's/^/  /'
  else
    warn "LaunchAgent is NOT registered (not installed or failed to load)"
  fi

  echo ""
  echo -e "${BOLD}Version check:${RESET}"
  if brew outdated --cask --greedy 2>/dev/null | grep -q "^claude-code"; then
    warn "Update available! Run: brew upgrade --cask --greedy claude-code"
  else
    local current
    current=$(brew list --cask --versions claude-code 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    success "Up-to-date: $current"
  fi

  echo ""
  echo -e "${BOLD}Last 20 log lines:${RESET}"
  if [[ -f "$LOG" ]]; then
    tail -20 "$LOG"
  else
    echo "  (no log yet)"
  fi
  echo ""
}

cmd_now() {
  preflight

  if ! agent_registered; then
    die "Auto-updater is not installed. Run $(basename "$0") first."
  fi

  info "Triggering update check via launchd..."
  launchctl kickstart -k "gui/$(id -u)/$LABEL"

  echo ""
  info "Waiting for result..."
  sleep 4
  echo ""
  echo -e "${BOLD}Last 10 log lines:${RESET}"
  tail -10 "$LOG" 2>/dev/null || echo "  (log not found — check $ERR_LOG)"
}

cmd_uninstall() {
  echo ""
  echo -e "${BOLD}Uninstalling Claude Code Auto-Update${RESET}"
  echo "──────────────────────────────────────"

  info "Unregistering LaunchAgent..."
  bootout_agent
  success "LaunchAgent unregistered"

  info "Removing plist..."
  rm -f "$PLIST"
  success "Plist removed"

  info "Removing updater script..."
  rm -f "$SCRIPT"
  rm -rf "$LOCKDIR" 2>/dev/null || true
  success "Script removed"

  echo ""
  echo -e "${GREEN}${BOLD}Done.${RESET} Log files kept at:"
  echo "  $LOG"
  echo "  $ERR_LOG"
  echo ""
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-}" in
  --now)       cmd_now       ;;
  --status)    cmd_status    ;;
  --uninstall) cmd_uninstall ;;
  "")          cmd_install   ;;
  *)
    echo "Usage: $(basename "$0") [--now | --status | --uninstall]"
    exit 1
    ;;
esac
