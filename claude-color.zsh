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
#   CLAUDE_COLOR_TEXT="#hex"          regular text color while tinted
#   CLAUDE_COLOR_ACCENT=<mode|#hex>   bold/cursor: pair, white, complement, tint, or a hex

typeset -g CLAUDE_COLOR_HOME=${${(%):-%x}:P:h}
: ${CLAUDE_COLOR_CONFIG:=$HOME/.config/claude-color/overrides}
: ${CLAUDE_COLOR_ACCENT_FILE:=$HOME/.config/claude-color/accent}

# Append only: reordering changes every project's automatic color.
typeset -ga CLAUDE_COLOR_PALETTE
(( ${#CLAUDE_COLOR_PALETTE} )) || CLAUDE_COLOR_PALETTE=(
  navy=#1b2a3d  plum=#2b1f3d   forest=#1a3328  walnut=#3a2a1a
  wine=#3a1c2a  teal=#16343a   olive=#2c3519   oxblood=#3b1f1f
  indigo=#24243f slate=#1f2f3a cocoa=#35281f   pine=#203a33
)

# Groups for the /claude-color picker ("Label:name name ..."). At most 4 names
# each, because the picker shows 4 choices at a time.
typeset -ga CLAUDE_COLOR_GROUPS
(( ${#CLAUDE_COLOR_GROUPS} )) || CLAUDE_COLOR_GROUPS=(
  "Blues & purples:navy slate indigo plum"
  "Greens:forest pine olive teal"
  "Warm:walnut cocoa wine oxblood"
)

# Hand-picked accent (bold text + cursor) for each palette color: a soft,
# muted complement that stands out without glaring. Used by accent mode "pair".
typeset -gA CLAUDE_COLOR_PAIRS
(( ${#CLAUDE_COLOR_PAIRS} )) || CLAUDE_COLOR_PAIRS=(
  navy '#d9b26f'    slate '#d8b98a'   indigo '#dcb877'  plum '#d6c58c'
  forest '#e8b4bc'  pine '#e0aeb2'    olive '#c6b4dc'   teal '#e3b29a'
  walnut '#a9c4dc'  cocoa '#a8ccc8'   wine '#b2d2b6'    oxblood '#a6cfc2'
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

# Nearest palette name to any hex (by RGB distance), for accent pairs.
_claude_color_nearest() {
  local h=${1#\#} entry e best="" bestd=999999 d
  local r=$((16#${h[1,2]})) g=$((16#${h[3,4]})) b=$((16#${h[5,6]}))
  for entry in $CLAUDE_COLOR_PALETTE; do
    [[ $entry == *=* ]] || continue
    e=${${entry#*=}#\#}
    d=$(( (r-16#${e[1,2]})**2 + (g-16#${e[3,4]})**2 + (b-16#${e[5,6]})**2 ))
    (( d < bestd )) && { bestd=$d; best=${entry%%=*}; }
  done
  [[ -n $best ]] && print -r -- "$best"
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

# Accent (bold text + cursor) for a background. Modes, chosen by
# `claude-color accent <mode>` (saved in $CLAUDE_COLOR_ACCENT_FILE) or by
# CLAUDE_COLOR_ACCENT (a mode or a #hex):
#   pair        hand-picked muted complement per color (default; forest ->
#               pale pink, navy -> muted gold); custom hexes use the nearest
#   white       pure white bold over slightly dimmer text
#   complement  the opposite hue, light (navy -> pale amber)
#   tint        the same hue, light (navy -> pale blue)
_claude_color_accent_mode() {
  local m=$CLAUDE_COLOR_ACCENT
  [[ -z $m && -r $CLAUDE_COLOR_ACCENT_FILE ]] && read -r m < "$CLAUDE_COLOR_ACCENT_FILE"
  print -r -- "${m:-pair}"
}

# Light version of an rgb triple: scale until the top channel is 255, then
# blend 55/45 with white.
_claude_color_lighten() {
  local m=1 c out="#"
  for c in "$@"; do (( c > m )) && m=$c; done
  for c in "$@"; do out+=$(printf '%02x' $(( (c * 255 / m) * 55 / 100 + 255 * 45 / 100 ))); done
  print -r -- "$out"
}

_claude_color_accent() {
  local mode=$(_claude_color_accent_mode) h=${1#\#}
  local r=$((16#${h[1,2]})) g=$((16#${h[3,4]})) b=$((16#${h[5,6]})) s
  case $mode in
    \#*)       print -r -- "$mode" ;;
    tint)       _claude_color_lighten $r $g $b ;;
    white)      print -r -- "#ffffff" ;;
    complement) local hi=$r lo=$r c
                for c in $g $b; do (( c > hi )) && hi=$c; (( c < lo )) && lo=$c; done
                s=$(( hi + lo ))  # rotate hue 180 degrees: c -> max + min - c
                _claude_color_lighten $(( s - r )) $(( s - g )) $(( s - b )) ;;
    *)          local n=$(_claude_color_nearest "#$h")
                print -r -- "${CLAUDE_COLOR_PAIRS[$n]:-#d9b26f}" ;;
  esac
}

# Regular text color: dimmed a little in white mode so bold stands out.
_claude_color_text() {
  [[ -n $CLAUDE_COLOR_TEXT ]] && { print -r -- "$CLAUDE_COLOR_TEXT"; return; }
  [[ $(_claude_color_accent_mode) == white ]] && print -r -- "#d2d2d2" || print -r -- "#e6e6e6"
}

# Paint background $1 on terminal $2 (plus light text and a matching accent).
_claude_color_apply() {
  local hex=$1 dev=$2 accent
  accent=$(_claude_color_accent "$hex")
  if [[ $TERM_PROGRAM == Apple_Terminal ]]; then
    _claude_color_terminal_tab "$dev" "set background color of t to {$(_claude_color_16bit $hex)}
            set normal text color of t to {$(_claude_color_16bit $(_claude_color_text))}
            set bold text color of t to {$(_claude_color_16bit $accent)}
            set cursor color of t to {$(_claude_color_16bit $accent)}" >/dev/null
  else
    printf '\e]11;%s\a\e]10;%s\a\e]12;%s\a' "$hex" "$(_claude_color_text)" "$accent" > "$dev"
  fi
}

# Terminal.app: current colors as "bg|text|bold|cursor".
_claude_color_save() {
  _claude_color_terminal_tab "$1" 'set out to ""
            repeat with c in {background color of t, normal text color of t, bold text color of t, cursor color of t}
              set out to out & (item 1 of c) & ", " & (item 2 of c) & ", " & (item 3 of c) & "|"
            end repeat
            return out'
}

_claude_color_restore() {
  local -a c=( ${(s:|:)2} )
  (( ${#c} >= 4 )) || return
  _claude_color_terminal_tab "$1" "set background color of t to {${c[1]}}
            set normal text color of t to {${c[2]}}
            set bold text color of t to {${c[3]}}
            set cursor color of t to {${c[4]}}" >/dev/null
}

# ---------------------------------------------------------------- wrapper

claude() {
  if [[ -n $CLAUDE_COLOR_DISABLE || ! -t 1 ]]; then
    command claude "$@"
    return
  fi

  local dev=$TTY saved
  [[ $TERM_PROGRAM == Apple_Terminal ]] && saved=$(_claude_color_save "$dev")
  _claude_color_apply "$(_claude_color_pick "$(_claude_color_key)")" "$dev"

  {
    CLAUDE_COLOR_ACTIVE=1 command claude "$@"
  } always {
    if [[ $TERM_PROGRAM == Apple_Terminal ]]; then
      _claude_color_restore "$dev" "$saved"
    else
      printf '\e]111\a\e]110\a\e]112\a'  # back to the profile's colors
    fi
  }
}
