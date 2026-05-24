#!/usr/bin/env bash

# 1. Configuration
PORT=9000
CREDENTIALS="admin:admin"
TMUX_SESSION="test"

# 2. Ensure tmux session exists (creates it in the background if missing)
if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo "Creating new tmux session: $TMUX_SESSION"
    tmux new-session -d -s "$TMUX_SESSION"
else
    echo "Attaching to existing tmux session: $TMUX_SESSION"
fi

# 3. Start ttyd
echo "Starting ttyd on port $PORT..."
ttyd -p "$PORT" \
     -c "$CREDENTIALS" \
     tmux attach -t "$TMUX_SESSION"
