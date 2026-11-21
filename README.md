# claude-color

Give every Claude Code session its own terminal background color, chosen by project.

`cd` into a project and run `claude` as usual. The window tints to that project's color while Claude runs and goes back to normal when it exits. The same project always gets the same color, so you can tell windows apart at a glance.

## Install

```sh
git clone https://github.com/adamzaidi/claude-color.git ~/claude-color
~/claude-color/install.sh
source ~/.zshrc
```

Requires zsh (the macOS default).

## How the color is picked

1. The project is the git root of the current directory, or the directory itself outside a repo.
2. If a line in `~/.config/claude-color/overrides` matches part of that path, its color is used.
3. Otherwise the path is hashed into a palette of 12 dark colors.

## Choosing colors

From inside Claude Code, in the window you're working in:

```
/claude-color                 show the palette and pick one
/claude-color plum            use a palette color
/claude-color #2a2240         use any hex
/claude-color something warm  describe it and Claude picks a color
/claude-color next            cycle to the next palette color
/claude-color reset           back to the automatic color
```

The window changes right away, and the choice is saved for that project, so every later `claude` launch there uses it.

The same works from a regular shell:

```sh
claude-color              # this project's color
claude-color list         # palette with swatches
claude-color teal         # set it (saved + applied now)
claude-color preview '#203040'   # try it without saving
claude-color next | reset | rules
```

Palette: navy, plum, forest, walnut, wine, teal, olive, oxblood, indigo, slate, cocoa, pine.

## Overrides

`~/.config/claude-color/overrides`:

```
# <text in the project path>  <#hex>
/Users/me/code/my-api   #3b1f1f
notes                   #1a3328
```

An absolute path matches that project exactly. Any other text matches every project whose path contains it. The first match wins, and `claude-color <color>` writes exact-path rules at the top.

## Settings

Put these in `~/.zshrc` before the `source` line:

| Variable | Effect |
| --- | --- |
| `CLAUDE_COLOR_DISABLE=1` | Turn it off without uninstalling |
| `CLAUDE_COLOR_PALETTE=(...)` | Use your own list of hex colors |
| `CLAUDE_COLOR_TEXT="#e6e6e6"` | Text color while tinted |
| `CLAUDE_COLOR_CONFIG=path` | Use a different overrides file |

## Terminal support

- **Terminal.app**: uses AppleScript on the tab that owns your shell, and saves and restores your exact colors. The first run asks to let Terminal control Terminal. Click Allow.
- **iTerm2, Ghostty, kitty, WezTerm, VS Code**: uses standard OSC 10/11 escape codes and resets to your profile's colors on exit.

## Uninstall

Delete the `source .../claude-color.zsh` line from `~/.zshrc` and remove `~/.claude/skills/claude-color`.

## License

MIT
