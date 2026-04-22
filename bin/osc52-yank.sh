#!/usr/bin/env bash
# OSC 52 copy script for tmux-yank
# Reads from stdin and sends to terminal using OSC 52

# Read the content
content=$(cat)

# Encode in base64
encoded=$(echo -n "$content" | base64 | tr -d '\n')

# Send the escape sequence
# Use \033]52;c; (c for clipboard)
printf "\033]52;c;%s\a" "$encoded"
