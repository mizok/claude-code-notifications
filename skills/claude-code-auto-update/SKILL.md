---
name: claude-code-auto-update
description: Use when the user wants to set up automatic daily Claude Code version checking and updating on macOS, or wants to check status or uninstall the auto-updater.
---

# Claude Code Auto-Update

## Overview

Sets up a macOS LaunchAgent that checks for new Claude Code versions daily via Homebrew and upgrades automatically. Powered by `install.sh` in this skill directory — no manual steps needed.

> **Requirements:** macOS, Homebrew, Claude Code installed via `brew install --cask claude-code`

> **Security note:** This enables automatic remote upgrades. Homebrew verifies cask checksums, but auto-upgrades are a supply-chain trust decision. Users who prefer to upgrade manually can skip the scheduler and use `--now` on demand instead.

---

## Usage

Locate `install.sh` in the same directory as this skill, then run:

```bash
# First time setup (interactive — asks for preferred time)
./install.sh

# Check status + last log
./install.sh --status

# Trigger an immediate update check right now
./install.sh --now

# Remove everything
./install.sh --uninstall
```

---

## What the script does

| Command | Action |
|---------|--------|
| `./install.sh` | Preflight checks → asks for daily time → writes `~/.local/bin/claude-code-autoupdate.sh` → registers LaunchAgent |
| `--status` | Shows LaunchAgent state, current version, last 20 log lines |
| `--now` | Kicks off an immediate check via `launchctl kickstart` (same env as scheduled job) |
| `--uninstall` | Unregisters LaunchAgent, removes plist and script; keeps log files |

Logs are written to `~/.claude/autoupdate.log`.

---

## How to run install.sh as an AI agent

When the user asks you to set up auto-update, run the script directly:

```bash
bash /path/to/skills/claude-code-auto-update/install.sh
```

If you need to pass a time non-interactively (e.g. user said "every day at 8am"), the script is interactive — just run it and answer the prompt with the user's chosen time.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `brew --prefix` fails | Homebrew may be broken — run `brew doctor` |
| LaunchAgent not registered after install | Run `./install.sh --uninstall` then reinstall |
| `--now` hangs or produces no log | Check `~/.claude/autoupdate-error.log` |
| Lock dir stuck after crash | `rm -rf ~/.claude/autoupdate.lock` |
| `claude` shows old version after update | Check `command -v claude` — PATH may point to a non-Homebrew install |
| Cask skips upgrade | Script uses `--greedy` to force-check casks with `auto_updates true` |
