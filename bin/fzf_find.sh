#!/bin/bash
# Call fd and fzf to select a file with bat preview
fd . --type f | fzf --preview "bat --color=always --style=numbers {}" > /tmp/fzf_result.txt

# Read the selected file from the temp file
selected_file=$(cat /tmp/fzf_result.txt)

# If a file was selected, send it to lf with Unix-style paths
if [ -n "$selected_file" ]; then
    lf -remote "send $id select '$selected_file'"
fi

# Clean up the temp file
rm /tmp/fzf_result.txt
