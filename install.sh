#!/usr/bin/env bash
# Installs claude-color:
#   - copies the shell plugin to ~/.local/share/claude-color (a stable path, so
#     updating the repo or the Claude Code plugin never breaks your ~/.zshrc)
#   - sources it from ~/.zshrc
#   - creates ~/.config/claude-color/overrides
#   - links the /claude-color skill into ~/.claude/skills (skipped with
#     --no-skill, e.g. when the skill comes from the Claude Code plugin)
# Safe to re-run; re-running also updates the installed copy.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
link_skill=1
[[ ${1:-} == --no-skill ]] && link_skill=0

dest="$HOME/.local/share/claude-color"
mkdir -p "$dest/bin"
cp "$here/claude-color.zsh" "$dest/"
cp "$here/bin/claude-color" "$dest/bin/"
mkdir -p "$dest/scripts"
cp "$here/scripts/prompt-hook.sh" "$dest/scripts/"
chmod +x "$dest/bin/claude-color" "$dest/scripts/prompt-hook.sh"
echo "Installed shell plugin to $dest"

rc="$HOME/.zshrc"
line="source \"$dest/claude-color.zsh\""
touch "$rc"
if grep -qF "$line" "$rc"; then
  echo "Already sourced from $rc"
else
  # Drop any older claude-color source line (e.g. one pointing at a clone).
  tmp=$(mktemp)
  grep -vE '^source .*/claude-color\.zsh"?$|^# claude-color: per-project' "$rc" > "$tmp" || true
  cat "$tmp" > "$rc"; rm -f "$tmp"
  printf '\n# claude-color: per-project terminal tint for Claude Code\n%s\n' "$line" >> "$rc"
  echo "Added to $rc"
fi

cfg="$HOME/.config/claude-color/overrides"
if [[ ! -e $cfg ]]; then
  mkdir -p "$(dirname "$cfg")"
  cp "$here/overrides.example" "$cfg"
  echo "Created $cfg"
fi

if (( link_skill )); then
  skills="$HOME/.claude/skills"
  mkdir -p "$skills"
  if [[ -L $skills/claude-color || ! -e $skills/claude-color ]]; then
    ln -sfn "$here/skills/claude-color" "$skills/claude-color"
    echo "Linked /claude-color skill into $skills"
  else
    echo "Skipped skill: $skills/claude-color already exists and is not a link"
  fi
fi

# Instant "/claude-color <name>": a UserPromptSubmit hook in ~/.claude/settings.json.
# (The Claude Code plugin ships this hook itself, so it's skipped with --no-skill.)
if (( link_skill )); then
  settings="$HOME/.claude/settings.json"
  hook="$dest/scripts/prompt-hook.sh"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$settings" "$hook" <<'PY'
import json, os, sys
path, hook = sys.argv[1], sys.argv[2]
d = json.load(open(path)) if os.path.exists(path) else {}
ups = d.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
cmds = [h.get("command", "") for e in ups for h in e.get("hooks", [])]
if not any("prompt-hook.sh" in c and "claude-color" in c for c in cmds):
    ups.append({"hooks": [{"type": "command", "command": f'"{hook}"'}]})
    json.dump(d, open(path, "w"), indent=2)
    open(path, "a").write("\n")
    print(f"Added instant /claude-color hook to {path}")
else:
    print(f"Instant /claude-color hook already in {path}")
PY
  else
    echo "python3 not found: add a UserPromptSubmit hook running \"$hook\" to $settings for instant /claude-color"
  fi
fi

echo "Open a new terminal window (or run: source ~/.zshrc), then run claude."
