# claude-color

A zsh plugin that wraps `claude` so that each project tints the terminal background.

## Layout

- `claude-color.zsh`: the library plus the `claude` wrapper function. It is sourced from `~/.zshrc` and adds `bin/` to PATH.
- `bin/claude-color`: CLI for choosing colors (set, default, preview, list, and `menu`, which prints the picker data). It sources the library.
- `skills/claude-color/SKILL.md`: the `/claude-color` skill. It calls `${CLAUDE_SKILL_DIR}/../../bin/claude-color`, which resolves both in a plugin install and through the `~/.claude/skills` symlink of a clone install. With no arguments it lists the color names. The user found a picker menu too slow, so there's deliberately no menu.
- `.claude-plugin/`: `plugin.json` and `marketplace.json`. The repo is both the marketplace and the plugin (`source: "./"`). **The plugin is named `color` and the marketplace `claude-color`** (install: `claude plugin install color --marketplace adamzaidi/claude-color`). Names starting with `claude-` are reserved, so it can't be claude-color; the skill and repo keep that name. Run `claude plugin validate .` after any change.
- `scripts/prompt-hook.sh` (UserPromptSubmit): applies `/claude-color <name|#hex|default|accent X>` the instant the prompt is submitted, then passes it through with `additionalContext` telling Claude to reply with just the result line. It doesn't block, because Claude Code labels every blocked prompt "blocked by hook", which the user disliked. `CLAUDE_COLOR_HOOK_BLOCK=1` restores blocking (no model turn). Multi-word or unknown arguments pass through to the skill. The plugin registers it in `hooks/hooks.json`; a clone install adds it to `~/.claude/settings.json`. The user explicitly does NOT want `/color` (prompt bar) suggestions: only the window changes.
- `hooks/hooks.json` + `scripts/session-start.sh`: a SessionStart hook that tells Claude when the session wasn't launched through the wrapper (no `CLAUDE_COLOR_ACTIVE`), so it can offer `/claude-color setup`.
- `install.sh`: idempotent. It copies the lib and bin to `~/.local/share/claude-color` (a stable path, because the plugin cache path changes with each version), points `~/.zshrc` there (replacing older lines), seeds overrides, and links the skill unless given `--no-skill`.
- `docs/demo.gif`: synthetic, rendered with PIL and encoded with ffmpeg. It's drawn rather than screen-recorded, so no real desktop content can leak into it.
- `overrides.example`: template for the overrides file.

## Decisions

- **The project key is the git root**, so subfolders of a repo share a color. Outside a repo it is `$PWD`.
- **Hash = `cksum` of the key, mod palette size.** This is stable across machines and shells. Changing the palette order changes everyone's automatic colors, so append rather than reorder. (On 2026-11-21 the palette was cut to six at the user's request: navy, slate, forest, dune, oxblood, poe.)
- **Terminal.app ignores OSC 11**, so it uses AppleScript instead. The script finds the tab whose `tty` equals zsh's `$TTY` rather than using "front window", so switching windows during startup doesn't tint the wrong one. Some windows (such as Settings) have no tabs, which is why each one is wrapped in `try`.
- Colors are saved before tinting and restored in a zsh `always` block, so Ctrl-C and crashes still restore them.
- **Accent (bold text + cursor):** the default mode is `pair`: per palette color, the secondary color of a college football team whose primary matches the background (user's idea), stored in `CLAUDE_COLOR_PAIRS` with the team in a comment. Custom hexes use the pair of the nearest palette color. The user rejected the alternatives in order: same-hue tint didn't stand out, and white bold over light-gray text was too similar. They asked for something like pale pink on forest or muted gold. Other modes: `complement` (hue rotated 180 degrees: c -> max+min-c, then lightened, which is vivid), `tint`, `white` (dims regular text to #d2d2d2). The mode is saved in `~/.config/claude-color/accent` by `claude-color accent`, and `CLAUDE_COLOR_ACCENT` overrides it. Terminal.app sets *bold text color* and *cursor color*; elsewhere it's OSC 12. Save and restore cover `bg|text|bold|cursor`.
- **Light backgrounds:** `_claude_color_is_light` (rough luma > 120 of 255) switches regular text to #2a2117 and darkens the accent to 40%. It was added for dune = #e3cfa8 (bone sand), which the user picked after previewing five shades.
- Text color is forced light (`CLAUDE_COLOR_TEXT`) because the palette is all dark. That keeps it readable even when the user's profile is a light theme.
- **Painting from inside Claude:** tool commands have no TTY, so `_claude_color_tty` goes up the process tree to the first ancestor that has one (the `claude` process) and paints that device. When Claude exits, the wrapper still restores the colors it saved at launch.
- **Override rules:** a pattern that starts with `/` must match the git root exactly. Anything else is a substring match. `claude-color set` rewrites that project's exact rule and moves it to the top so it beats substring rules. Each line is parsed by `_claude_color_parse_rule`: the color is the last field and the pattern is everything before it, because paths can contain spaces (e.g. iCloud's `Mobile Documents`). Don't go back to `read -r pattern color`.
- **Palette entries are `name=#hex`.** Plain `#hex` also works for user palettes, which then have no names.
- **zsh gotchas:** `${${x#*=}:l}`, not `${x#*=:l}`. `(#c3)` globs need `extendedglob`. `${${(On)arr}[1]}` indexes characters, not elements, so use arithmetic loops for min and max.
- It skips everything when stdout is not a TTY (`claude -p ... | jq`) or when `CLAUDE_COLOR_DISABLE` is set.

## Testing

There's no test suite. Check it by hand in Terminal.app and in one OSC terminal (Ghostty or iTerm2): run `claude`, check the tint, exit, and confirm the colors are restored. Also try Ctrl-C at startup.
