# claude-color — tint the terminal per project whenever you run `claude`.
#
# Source this file from ~/.zshrc. It wraps the `claude` command so that:
#   1. the project (git root, or the current directory) gets a color,
#   2. the terminal background is set to that color while Claude runs,
#   3. the original colors are restored when Claude exits (even on Ctrl-C).
#
# It also puts the `claude-color` command on your PATH for choosing colors
# (see `claude-color help`), which the /claude-color skill uses inside Claude.
#
# Settings (set before sourcing, or export in ~/.zshrc):
#   CLAUDE_COLOR_DISABLE=1            turn it off without uninstalling
#   CLAUDE_COLOR_CONFIG=<path>        overrides file (default ~/.config/claude-color/overrides)
#   CLAUDE_COLOR_PALETTE=(...)        your own colors: "name=#hex" or "#hex"
#   CLAUDE_COLOR_TEXT="#e6e6e6"       text color used while tinted

typeset -g CLAUDE_COLOR_HOME=${${(%):-%x}:A:h}
: ${CLAUDE_COLOR_CONFIG:=$HOME/.config/claude-color/overrides}
: ${CLAUDE_COLOR_TEXT:=#e6e6e6}

# Append only: reordering changes every project's automatic color.
typeset -ga CLAUDE_COLOR_PALETTE
(( ${#CLAUDE_COLOR_PALETTE} )) || CLAUDE_COLOR_PALETTE=(
  navy=#1b2a3d  plum=#2b1f3d   forest=#1a3328  walnut=#3a2a1a
  wine=#3a1c2a  teal=#16343a   olive=#2c3519   oxblood=#3b1f1f
  indigo=#24243f slate=#1f2f3a cocoa=#35281f   pine=#203a33
)

# Put bin/ on PATH for interactive shells.
[[ :$PATH: == *:$CLAUDE_COLOR_HOME/bin:* ]] || path+=("$CLAUDE_COLOR_HOME/bin")

# ---------------------------------------------------------------- picking

# The project a directory belongs to: its git root, or the directory itself.
_claude_color_key() {
  local root
  root=$(git -C "${1:-$PWD}" rev-parse --show-toplevel 2>/dev/null) || root=${1:-$PWD}
  print -r -- "${root:A}"
}

# Rule matches key? Absolute paths match exactly; anything else is a substring.
_claude_color_rule_matches() {
  local pattern=$1 key=$2
  if [[ $pattern == /* ]]; then [[ $key == "${pattern:A}" ]]
  else [[ $key == *"$pattern"* ]]
  fi
}

# Override color for a key, if any (first matching rule wins).
_claude_color_override() {
  local key=$1 pattern color
  [[ -r $CLAUDE_COLOR_CONFIG ]] || return 1
  while read -r pattern color _; do
    [[ -z $pattern || $pattern == \#* || -z $color ]] && continue
    if _claude_color_rule_matches "$pattern" "$key"; then
      print -r -- "$color"; return 0
    fi
  done < "$CLAUDE_COLOR_CONFIG"
  return 1
}

# Palette index (1-based) a key hashes to.
_claude_color_hash_index() {
  local sum
  sum=$(print -rn -- "$1" | cksum); sum=${sum%% *}
  print -r -- $(( sum % ${#CLAUDE_COLOR_PALETTE} + 1 ))
}

# Hex color for a project: override, else a stable hash pick.
_claude_color_pick() {
  _claude_color_override "$1" && return
  local entry=${CLAUDE_COLOR_PALETTE[$(_claude_color_hash_index "$1")]}
  print -r -- "${entry#*=}"
}

# Palette name for a hex, if it has one.
_claude_color_name_of() {
  local entry
  for entry in $CLAUDE_COLOR_PALETTE; do
    [[ $entry == *=* && ${${entry#*=}:l} == ${1:l} ]] && { print -r -- "${entry%%=*}"; return 0; }
  done
  return 1
}

# Resolve a palette name or hex ("#abc", "abc123") to "#rrggbb".
_claude_color_resolve() {
  setopt localoptions extendedglob
  local want=${1:l} entry
  for entry in $CLAUDE_COLOR_PALETTE; do
    [[ $entry == *=* && ${entry%%=*} == $want ]] && { print -r -- "${entry#*=}"; return 0; }
  done
  want=${want#\#}
  if [[ $want == [0-9a-f](#c3) ]]; then
    want=${want[1]}${want[1]}${want[2]}${want[2]}${want[3]}${want[3]}
  fi
  [[ $want == [0-9a-f](#c6) ]] && { print -r -- "#$want"; return 0; }
  return 1
}

# ---------------------------------------------------------------- applying

# "#rrggbb" -> "r, g, b" in Terminal.app's 16-bit scale.
_claude_color_16bit() {
  local h=${1#\#}
  print -r -- "$(( 16#${h[1,2]} * 257 )), $(( 16#${h[3,4]} * 257 )), $(( 16#${h[5,6]} * 257 ))"
}

# The terminal device to paint: our own TTY, or (when run from inside Claude,
# which has no TTY for tool commands) the nearest ancestor process's TTY.
_claude_color_tty() {
  if [[ -n $TTY && $TTY != "not a tty" ]]; then print -r -- "$TTY"; return; fi
  local pid=$$ t pp
  while (( pid > 1 )); do
    read -r t pp <<<"$(ps -o tty=,ppid= -p $pid 2>/dev/null)" || return 1
    [[ -n $t && $t != '??' ]] && { print -r -- "/dev/$t"; return 0; }
    pid=$pp
  done
  return 1
}

# Run AppleScript against the Terminal.app tab that owns $1 (a tty path).
# $2 is the body, with the tab bound to `t`.
_claude_color_terminal_tab() {
  osascript - "$1" <<EOF 2>/dev/null
on run argv
  set myTTY to item 1 of argv
  tell application "Terminal"
    repeat with w in windows
      try
        repeat with t in tabs of w
          if tty of t is myTTY then
            $2
          end if
        end repeat
      end try
    end repeat
  end tell
end run
EOF
}

# Paint background $1 on terminal $2.
_claude_color_apply() {
  local hex=$1 dev=$2
  if [[ $TERM_PROGRAM == Apple_Terminal ]]; then
    _claude_color_terminal_tab "$dev" "set background color of t to {$(_claude_color_16bit $hex)}
            set normal text color of t to {$(_claude_color_16bit $CLAUDE_COLOR_TEXT)}" >/dev/null
  else
    printf '\e]11;%s\a\e]10;%s\a' "$hex" "$CLAUDE_COLOR_TEXT" > "$dev"
  fi
}

# ---------------------------------------------------------------- wrapper

claude() {
  if [[ -n $CLAUDE_COLOR_DISABLE || ! -t 1 ]]; then
    command claude "$@"
    return
  fi

  local dev=$TTY saved
  if [[ $TERM_PROGRAM == Apple_Terminal ]]; then
    saved=$(_claude_color_terminal_tab "$dev" \
      'set b to background color of t
            set f to normal text color of t
            return ((item 1 of b) as text) & ", " & (item 2 of b) & ", " & (item 3 of b) & "|" & (item 1 of f) & ", " & (item 2 of f) & ", " & (item 3 of f)')
  fi
  _claude_color_apply "$(_claude_color_pick "$(_claude_color_key)")" "$dev"

  {
    command claude "$@"
  } always {
    if [[ $TERM_PROGRAM == Apple_Terminal ]]; then
      [[ $saved == *\|* ]] && _claude_color_terminal_tab "$dev" \
        "set background color of t to {${saved%%|*}}
            set normal text color of t to {${saved##*|}}" >/dev/null
    else
      printf '\e]111\a\e]110\a'  # back to the profile's colors
    fi
  }
}
