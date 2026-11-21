# claude-color

A zsh plugin that wraps `claude` so that each project tints the terminal background.

## Layout

- `claude-color.zsh`: the library plus the `claude` wrapper function. It is sourced from `~/.zshrc` and adds `bin/` to PATH.
- `bin/claude-color`: CLI for choosing colors (set, next, reset, preview, list). It sources the library.
- `skill/`: the `/claude-color` Claude Code skill. `install.sh` symlinks it to `~/.claude/skills/claude-color`. `skill/claude-color` is a relative symlink to `../bin/claude-color`, so the skill can call `~/.claude/skills/claude-color/claude-color` without knowing where the repo lives.
- `install.sh`: idempotent. It adds the source line, seeds the overrides file and links the skill.
- `overrides.example`: template for the overrides file.

## Decisions

- **The project key is the git root**, so subfolders of a repo share a color. Outside a repo it is `$PWD`.
- **Hash = `cksum` of the key, mod palette size.** This is stable across machines and shells. Changing the palette order changes everyone's colors, so append rather than reorder.
- **Terminal.app ignores OSC 11**, so it uses AppleScript instead. The script finds the tab whose `tty` equals zsh's `$TTY` rather than using "front window", so switching windows during startup doesn't tint the wrong one. Some windows (such as Settings) have no tabs, which is why each one is wrapped in `try`.
- Colors are saved before tinting and restored in a zsh `always` block, so Ctrl-C and crashes still restore them.
- Text color is forced light (`CLAUDE_COLOR_TEXT`) because the palette is all dark. That keeps it readable even when the user's profile is a light theme.
- **Painting from inside Claude:** tool commands have no TTY, so `_claude_color_tty` goes up the process tree to the first ancestor that has one (the `claude` process) and paints that device. When Claude exits, the wrapper still restores the colors it saved at launch.
- **Override rules:** a pattern that starts with `/` must match the git root exactly. Anything else is a substring match. `claude-color set` rewrites that project's exact rule and moves it to the top so it beats substring rules.
- **Palette entries are `name=#hex`.** Plain `#hex` also works for user palettes, which then have no names.
- **zsh gotchas:** `${${x#*=}:l}`, not `${x#*=:l}`. `(#c3)` globs need `extendedglob`.
- It skips everything when stdout is not a TTY (`claude -p ... | jq`) or when `CLAUDE_COLOR_DISABLE` is set.

## Testing

There's no test suite. Check it by hand in Terminal.app and in one OSC terminal (Ghostty or iTerm2): run `claude`, check the tint, exit, and confirm the colors are restored. Also try Ctrl-C at startup.
