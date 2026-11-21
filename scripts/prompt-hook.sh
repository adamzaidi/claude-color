#!/bin/zsh
# UserPromptSubmit hook: applies "/claude-color <args>" (or "claude-color <args>")
# the instant the prompt is submitted, then stops the prompt with continue:false so
# there's no model turn (zero tokens). Claude Code shows it as
# "Operation stopped by hook: <stopReason>"; that prefix is hard-coded, so the
# stopReason is worded as a success ("Window is now slate (#1f2f3a)").
# CLAUDE_COLOR_HOOK_REPLY=1: pass the prompt through and have Claude echo the result
#   (no label, but costs a model turn).
# CLAUDE_COLOR_HOOK_BLOCK=1: decision:block ("UserPromptSubmit operation blocked by hook:").
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
  ""|default|reset|auto|list|ls|rules|status) (( ${#args} <= 1 )) || exit 0 ;;
  accent|preview) (( ${#args} <= 2 )) || exit 0 ;;
  *) (( ${#args} == 1 )) && _claude_color_resolve "${args[1]}" >/dev/null || exit 0 ;;
esac

if (( ${#args} == 0 )); then
  names=(); for e in $CLAUDE_COLOR_PALETTE; do names+=(${e%%=*}); done
  msg="Colors: ${(j:, :)names}. Type /claude-color <name>, a #hex, default, or accent <pair|white|complement|tint>."
else
  out=$("$tool" "${args[@]}" 2>&1)
  if [[ $? -ne 0 ]]; then
    msg=$out
  else
    lines=( "${(@f)out}" ); first=${lines[1]%%  \[*}
    case ${args[1]} in
      accent|preview|list|ls|rules) msg=${(j: | :)lines} ;;
      *) msg="Window is now $first" ;;
    esac
  fi
fi
json() { local m=${1//\\/\\\\}; print -r -- "${m//\"/\\\"}"; }
if [[ -n $CLAUDE_COLOR_HOOK_BLOCK ]]; then
  print -r -- "{\"decision\":\"block\",\"reason\":\"$(json "$msg")\",\"suppressOriginalPrompt\":true}"
elif [[ -z $CLAUDE_COLOR_HOOK_REPLY ]]; then
  print -r -- "{\"continue\":false,\"stopReason\":\"$(json "$msg")\"}"
else
  ctx="claude-color hook: this command was already applied, and the result is: $msg -- Do not run any tools. Reply with exactly that result as one line, nothing else."
  print -r -- "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"$(json "$ctx")\"}}"
fi
