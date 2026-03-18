---
name: claude-code-notifications
description: Use when the user wants to set up sound and custom icon for Claude Code hook notifications on macOS, or when notifications have no sound.
---

# Claude Code Notification Setup

## Overview

Interactively set up sound and custom icon for Claude Code `Notification` hooks on macOS using [growlrrr](https://github.com/moltenbits/growlrrr).

## Prerequisites Check

**Before doing anything else**, verify the environment:

### 1. Must be macOS

```bash
uname -s
```

If the output is NOT `Darwin`, stop immediately and tell the user:
> This skill only works on macOS. growlrrr and the Notification hook are not supported on Linux or Windows.

### 2. Must be Claude Code

Check if running inside Claude Code by verifying the `~/.claude/settings.json` file exists:

```bash
test -f ~/.claude/settings.json && echo "ok" || echo "not found"
```

If not found, stop and tell the user:
> This skill is designed for Claude Code. It does not apply to Codex, Cursor, or other AI tools.

---

## Execution Steps

Follow these steps in order when this skill is invoked:

### Step 1 — Ask the user for preferences

Ask the user two things (can be in one message):

1. **Icon**: Provide an image URL or local file path for the notification icon (PNG recommended). Or skip to use the default growlrrr icon.
2. **Sound**: Which sound do you want?

| Option | Sound |
|--------|-------|
| `Glass` | Clear, crisp (recommended) |
| `Ping` | Short single tone |
| `Tink` | Soft, subtle |
| `Sosumi` | Classic Mac |
| `Basso` | Low, deep |
| `none` | No sound |

### Step 2 — Install growlrrr

```bash
brew tap moltenbits/tap && brew install growlrrr
```

If already installed, skip.

```bash
which grrr
```

### Step 3 — Remove macOS quarantine flag

growlrrr is not yet signed by an Apple Developer account:

```bash
xattr -cr /Applications/growlrrr.app
```

### Step 4 — Download icon (if user provided a URL)

If the user gave a URL, download it:

```bash
curl -fsSL "<URL>" -o /tmp/notification-icon.png
```

If the user gave a local path, use it directly.

If the user skipped, omit `--appIcon` in Step 5.

### Step 5 — Create custom app

```bash
grrr apps add --appId Claude-Code --appIcon '/tmp/notification-icon.png'
# or without icon:
grrr apps add --appId Claude-Code
```

If `Claude-Code` already exists, remove it first:

```bash
grrr apps remove Claude-Code --force
```

### Step 6 — Test the notification

```bash
grrr --appId Claude-Code --title 'Claude Code' --sound <SOUND> 'Claude Code needs your attention'
```

Ask the user: did the notification appear with the correct icon and sound?

### Step 7 — Update `~/.claude/settings.json`

Add or replace the `Notification` hook:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "grrr --appId Claude-Code --title 'Claude Code' --sound <SOUND> 'Claude Code needs your attention'"
          }
        ]
      }
    ]
  }
}
```

### Step 8 — Grant notification permission (if first time)

Tell the user: go to **System Settings → Notifications → growlrrr** and make sure it's enabled.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No notification appears | System Settings → Notifications → growlrrr → enable |
| Command hangs | Run `xattr -cr /Applications/growlrrr.app` again |
| `appId` error | appId must use only letters, numbers, hyphens, underscores |
| Wrong icon showing | Make sure PNG is a valid image file, not an SVG or ICO |
| Hook has no effect | Restart Claude Code after editing `settings.json` |
