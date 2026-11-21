#!/bin/zsh
# UserPromptSubmit hook: applies "/claude-color <args>" (or "claude-color <args>")
# the instant the prompt is submitted, then lets the prompt through with a note
# so Claude just confirms in one line. Blocking would avoid the model turn, but
# Claude Code labels every blocked prompt "blocked by hook", which reads like an
# error. Set CLAUDE_COLOR_HOOK_BLOCK=1 to block anyway (no model turn).
# Every other prompt passes through untouched.
input=$(cat)
[[ $input == *'"prompt":"'(/|)'claude-color'* ]] || exit 0

prompt=${${input#*\"prompt\":\"}%%\"*}
[[ $prompt =~ '^/?claude-color( +[^ ]+)*$' ]] || exit 0   # one-liners only
args=( ${=${${prompt#*claude-color}//\'/}} )   # drop single quotes ('#hex')
cwd=${${input#*\"cwd\":\"}%%\"*}

tool="${0:P:h}/../bin/claude-color"
cd "$cwd" 2>/dev/null
source "${0:P:h}/../claude-color.zsh"

# Only handle what's instant and unambiguous; anything else (e.g. "something
# warmer") falls through to the /claude-color skill, where Claude interprets it.
case ${args[1]:-} in
  ""|next|reset|auto|list|ls|rules|status) (( ${#args} <= 1 )) || exit 0 ;;
  accent|preview) (( ${#args} <= 2 )) || exit 0 ;;
  *) (( ${#args} == 1 )) && _claude_color_resolve "${args[1]}" >/dev/null || exit 0 ;;
esac

if (( ${#args} == 0 )); then
  names=(); for e in $CLAUDE_COLOR_PALETTE; do names+=(${e%%=*}); done
  msg="Colors: ${(j:, :)names}. Type /claude-color <name>, a #hex, next, reset, or accent <pair|white|complement|tint>."
else
  out=$("$tool" "${args[@]}" 2>&1)
  if [[ $? -ne 0 ]]; then
    msg=$out
  else
    lines=( "${(@f)out}" ); first=${lines[1]%%  \[*}
    case ${args[1]} in
      accent|preview|list|ls|rules) msg=${(j: | :)lines} ;;
      *) msg="Window: $first" ;;
    esac
  fi
fi
json() { local m=${1//\\/\\\\}; print -r -- "${m//\"/\\\"}"; }
if [[ -n $CLAUDE_COLOR_HOOK_BLOCK ]]; then
  print -r -- "{\"decision\":\"block\",\"reason\":\"$(json "$msg")\",\"suppressOriginalPrompt\":true}"
else
  ctx="claude-color hook: this command was already applied, and the result is: $msg -- Do not run any tools. Reply with exactly that result as one line, nothing else."
  print -r -- "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"$(json "$ctx")\"}}"
fi
