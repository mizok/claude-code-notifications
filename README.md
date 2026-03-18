# claude-code-notifications

A [Claude Code](https://claude.ai/code) skill that sets up macOS notifications with custom sound and icon for Claude Code hooks.

By default, Claude Code hook notifications on macOS have no sound and use a generic icon. This skill installs [growlrrr](https://github.com/moltenbits/growlrrr) and configures everything interactively — you choose the icon and sound.

> **macOS only.** Requires Claude Code.

## Installation

### Via skills CLI (recommended)

```bash
npx skills add mizok/claude-code-notifications
```

### Via Claude Code plugin system

```
/plugin marketplace add mizok/claude-code-notifications
/plugin install claude-code-notifications@mizok-plugins
```

Then restart Claude Code.

## Usage

Once installed, just say:

```
/claude-code-notifications
```

Claude will guide you through:
1. Choosing a notification icon (URL or local file path)
2. Choosing a notification sound
3. Installing growlrrr
4. Configuring `~/.claude/settings.json`

## Requirements

- macOS 13 (Ventura) or later
- [Claude Code](https://claude.ai/code)
- [Homebrew](https://brew.sh)

## License

MIT
