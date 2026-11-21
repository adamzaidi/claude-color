---
name: claude-color
description: Change this terminal window's background tint for the current project (claude-color plugin). Use when the user runs /claude-color, or asks to change, pick, preview, cycle, or reset the window/terminal color.
argument-hint: "[name | #hex | description | next | reset | accent | setup]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/../../bin/claude-color:*), Bash(${CLAUDE_SKILL_DIR}/../../install.sh:*), AskUserQuestion
---

`claude-color` tints this terminal window and remembers the color for the current project (its git root). Changes apply immediately and are reused every time `claude` launches here.

Tool: `${CLAUDE_SKILL_DIR}/../../bin/claude-color`

Arguments: `$ARGUMENTS`

## No arguments: show the picker

1. Run `<tool> menu`. It prints the current color, its matching `/color` value, the project name, and the color groups.
2. Call AskUserQuestion with one question, "Pick a window color for <project>", header "Color", and these options, in this order:
   - First: label `<current name> (current)`, description `Keep <hex>`, or `Keep automatic color <hex>` when the source is automatic.
   - Then one option per `group:` line: label = the group's label, description = its color names joined with commas.
3. If they chose the current color, reply "Keeping <name>." and stop.
4. If they chose a group, call AskUserQuestion again with "Which shade?" and header "Shade". Give one option per color in that group: label = the name, plus ` (current)` if it is the current one; description = the hex. Then run `<tool> <name>`.
5. If they typed their own answer ("Other"), handle it like the arguments below.

## With arguments: run one command

| Arguments | Command |
| --- | --- |
| a palette name (navy, slate, indigo, plum, forest, pine, olive, teal, walnut, cocoa, wine, oxblood) | `<tool> <name>` |
| a hex like `#223344` | `<tool> '<hex>'` (quote it, because `#` starts a shell comment) |
| `next` / `reset` / `list` / `rules` | `<tool> <word>` |
| `accent` or `accent <white\|complement\|tint\|#hex>` | `<tool> accent <mode>`. This sets the bold-text and cursor color for every project. white = high-contrast white bold (default), complement = opposite hue, tint = same hue. With no mode, show the current one and those three choices with AskUserQuestion. |
| `preview <color>` | `<tool> preview '<color>'` (applies without saving) |
| `setup` | `${CLAUDE_SKILL_DIR}/../../install.sh --no-skill`, then tell them to open a new terminal window |
| a description ("darker blue", "something warm") | choose a dark hex for it (each channel under about `#45`, so the light text stays readable) and run `<tool> '<hex>'` |

## Reply

Reply with one short line: the color name and hex, then the matching prompt-bar command from the tool's `matching prompt bar:` line, e.g. "Window is now forest (#1a3328). For a matching bar, run `/color green`." You can't run `/color` yourself, because it's a built-in command. Don't explain the plugin.
