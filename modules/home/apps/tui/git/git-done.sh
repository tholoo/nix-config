#!/bin/bash
current_branch=$(git symbolic-ref --short HEAD)
default_branch=$(git remote show origin | grep "HEAD branch" | cut -d' ' -f5)

output=$(git push origin "$current_branch" -o merge_request.create -o merge_request.target="$default_branch" -o merge_request.remove_source_branch 2>&1)

echo "$output"

if [[ "$output" =~ https:// ]]; then
    mr_link=$(echo "$output" | grep -oP 'https://[^ ]+')
    echo "$mr_link"
    if command -v wl-copy &> /dev/null; then
        echo "$mr_link" | wl-copy
    fi
else
    echo "No Merge Request link found in output."
fi
