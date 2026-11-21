---
name: claude-color
description: Change this terminal window's background tint for the current project (claude-color plugin). Use when the user runs /claude-color, or asks to change, pick, preview, cycle, or reset the window/terminal color.
argument-hint: "navy | slate | forest | dune | oxblood | poe | #hex | default"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/../../bin/claude-color:*), Bash(${CLAUDE_SKILL_DIR}/../../install.sh:*)
---

`claude-color` tints this terminal window and remembers the color for the current project (its git root). Changes apply immediately and are reused every time `claude` launches here.

Tool: `${CLAUDE_SKILL_DIR}/../../bin/claude-color`

Arguments: `$ARGUMENTS`

**First check for a "claude-color hook" note in your context.** Simple forms (`/claude-color forest`, `#hex`, `default`, `accent <mode>`) are applied by the plugin's prompt hook before you see them. If the note is there, the change is already done: don't run anything, just reply with the result line it gives. Otherwise, follow the rules below.

## No arguments

Run `<tool> list` and reply with the color names on one line, followed by "Type `/claude-color <name>`." Don't open a picker.

## With arguments: run one command

| Arguments | Command |
| --- | --- |
| a palette name (navy, slate, forest, dune, oxblood, poe) | `<tool> <name>` |
| a hex like `#223344` | `<tool> '<hex>'` (quote it, because `#` starts a shell comment) |
| `default` (back to the automatic color) / `list` / `rules` | `<tool> <word>` |
| `accent` or `accent <pair\|white\|complement\|tint\|#hex>` | `<tool> accent <mode>`. This sets the bold-text and cursor color for every project. pair = a college football team's secondary color per background (default; forest gets Oregon yellow, poe gets LSU gold), complement = vivid opposite hue, tint = same hue, white = plain white. With no mode, run `<tool> accent` and reply with its line. |
| `preview <color>` | `<tool> preview '<color>'` (applies without saving) |
| `setup` | `${CLAUDE_SKILL_DIR}/../../install.sh --no-skill`, then tell them to open a new terminal window |
| a description ("darker blue", "something warm") | choose a hex for it (dark or light both work, since light backgrounds get dark text automatically) and run `<tool> '<hex>'` |

## Reply

Reply with one short line, the color name and hex, e.g. "Window is now forest (#1a3328)." Don't explain the plugin, and don't suggest `/color`.
