#!/usr/bin/env bash
# Source: https://morgan.cugerone.com/blog/workarounds-to-git-worktree-using-bare-repository-and-cannot-fetch-remote-branches/
# This script clones a git repository in a bare format suitable for worktrees.
# Usage examples:
# ./git-clone-bare.sh git@github.com:name/repo.git
# ./git-clone-bare.sh git@github.com:name/repo.git my-repo

set -euo pipefail
IFS=$'\n\t'

# Function to display usage help
usage() {
	echo "Usage: $0 [git clone options] -- <repository-url> [target-directory]"
	exit 1
}

# Find the index of the -- separator
sep_index=-1
for i in "$@"; do
	sep_index=$((sep_index + 1))
	[[ $i == "--" ]] && break
done

# No -- found or it's in the last position (no repo URL after --)
if [[ $sep_index -eq -1 ]] || [[ $sep_index -eq $# ]]; then
	usage
fi

# Split the arguments into git clone options and script arguments
git_clone_options=("${@:1:$sep_index}")
script_args=("${@:$((sep_index + 2))}") # +2 skips the -- itself

# Now, extract the script's own arguments
url=${script_args[0]}
name=$(basename "${url}")
name=${script_args[1]-${name%.*}}

# Proceed with the script
if mkdir -p "$name"; then
	echo "Directory '$name' created."
else
	echo "Error: Failed to create directory '$name'. It may already exist."
	exit 2
fi

cd "$name" || exit 3

# Pass the extracted git clone options along with the URL
git clone --bare "${git_clone_options[@]}" "$url" .bare
if [[ $? -eq 0 ]]; then
	echo "Repository cloned into .bare directory."
else
	echo "Error: Failed to clone repository."
	exit 4
fi

echo "gitdir: ./.bare" >.git
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
if git fetch origin; then
	echo "Successfully fetched all branches from origin."
else
	echo "Error: Failed to fetch branches from origin."
	exit 5
fi
