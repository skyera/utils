#!/bin/bash
# Call fd and fzf to select a file/dir with bat preview
tmpfile=$(mktemp /tmp/lf_fzf.XXXXXX)
fd . --type f --type d | fzf --preview "bat --color=always --style=numbers {}" > "$tmpfile"

# Read the selected file from the temp file
selected_file=$(cat "$tmpfile")

# If a file was selected, send it to lf with Unix-style paths
if [ -n "$selected_file" ]; then
    lf -remote "send $id select '$selected_file'"
fi

# Clean up the temp file
rm "$tmpfile"
