#!/usr/bin/env bash
# Adds claude-color to ~/.zshrc (once) and creates an empty overrides file.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
line="source \"$here/claude-color.zsh\""
rc="$HOME/.zshrc"

if grep -qF "$here/claude-color.zsh" "$rc" 2>/dev/null; then
  echo "Already installed in $rc"
else
  printf '\n# claude-color: per-project terminal tint for Claude Code\n%s\n' "$line" >> "$rc"
  echo "Added to $rc"
fi

cfg="$HOME/.config/claude-color/overrides"
if [[ ! -e $cfg ]]; then
  mkdir -p "$(dirname "$cfg")"
  cp "$here/overrides.example" "$cfg"
  echo "Created $cfg"
fi

skills="$HOME/.claude/skills"
mkdir -p "$skills"
if [[ -L $skills/claude-color || ! -e $skills/claude-color ]]; then
  ln -sfn "$here/skill" "$skills/claude-color"
  echo "Linked /claude-color skill into $skills"
else
  echo "Skipped skill: $skills/claude-color already exists and is not a link"
fi

echo "Open a new terminal window (or run: source ~/.zshrc), then run claude."
