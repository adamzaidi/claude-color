---
name: claude-color
description: Change this terminal window's background tint for the current project (claude-color plugin). Use when the user runs /claude-color, or asks to change, pick, preview, cycle, or reset the window/terminal color.
argument-hint: "[name | #hex | description | next | reset | list]"
allowed-tools: Bash(~/.claude/skills/claude-color/claude-color:*)
---

The `claude-color` tool tints this terminal window and remembers the color for the current project (its git root). It applies immediately, and it is used automatically every time `claude` launches here.

Tool: `~/.claude/skills/claude-color/claude-color`

Arguments: `$ARGUMENTS`

Run exactly one command based on the arguments, then reply in one short line with the result (the color name and hex). Don't explain the plugin.

| Arguments | Command |
| --- | --- |
| empty | `list`, then show the palette as a compact list, mark the current one, and invite them to pick |
| a palette name (navy, plum, forest, walnut, wine, teal, olive, oxblood, indigo, slate, cocoa, pine) | `<name>` |
| a hex like `#223344` | `'<hex>'` (quote it, because `#` starts a shell comment) |
| `next` / `reset` / `list` / `rules` | that word |
| `preview <color>` | `preview '<color>'` (applies without saving) |
| a description ("darker blue", "something warm", "midnight green") | choose a hex for it and run `'<hex>'` |

When choosing a hex yourself, keep it dark (each channel under about `#40`, or `#50` at most) so the light text stays readable. The tool sets text to `#e6e6e6`.
