#!/bin/sh
# Tells Claude when the shell side of claude-color isn't set up, so it can offer
# `/claude-color setup`. Silent once Claude is launched through the wrapper.
[ -n "$CLAUDE_COLOR_ACTIVE" ] && exit 0
echo "claude-color plugin: this session was not launched through the claude-color shell wrapper, so the window won't tint automatically at launch. /claude-color still changes the color live. If the user brings up window colors, mention that running \`/claude-color setup\` once enables automatic per-project colors."
