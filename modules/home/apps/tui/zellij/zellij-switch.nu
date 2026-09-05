#!/usr/bin/env -S nu --no-config-file

# Keep names and paths as data: display labels are never passed to Zellij.
let cache_home = $env.XDG_CACHE_HOME? | default ($env.HOME | path join ".cache")
let state_file = $cache_home | path join "zellij" "last-session"
let last_session = try { open --raw $state_file | str trim } catch { "" }
let inside_zellij = "ZELLIJ" in $env
let current_session = if $inside_zellij {
    $env.ZELLIJ_SESSION_NAME? | default ""
} else {
    ""
}

let session_result = ^zellij list-sessions --short --no-formatting | complete
let sessions = if $session_result.exit_code == 0 {
    $session_result.stdout | lines | where { |name| $name != "" } | uniq
} else {
    []
}
let other_sessions = $sessions | where { |name| $name != $current_session }
let ordered_sessions = if $last_session in $other_sessions {
    [$last_session] | append ($other_sessions | where { |name| $name != $last_session })
} else {
    $other_sessions
}
let session_options = $ordered_sessions | each { |name|
    {kind: "Session", name: $name, cwd: null, label: $name}
}

# An empty zoxide database (or missing zoxide) still allows session switching.
let directory_result = try { ^zoxide query --list | complete } catch { null }
let directories = if $directory_result != null and $directory_result.exit_code == 0 {
    $directory_result.stdout | lines | where { |dir| $dir != "" }
} else {
    []
}
let directory_options = $directories
    | each { |dir| $dir | path expand }
    | uniq
    | where { |dir| ($dir | path type) == "dir" }
    | each { |dir|
        let name = $dir | path basename | str replace --all --regex '[ .:]' '_'
        {kind: "Directory", name: $name, cwd: $dir, label: $dir}
    }
let options = $session_options | append $directory_options
if ($options | is-empty) { exit 0 }

let rows = $options | enumerate | each { |entry|
    $"($entry.index)\t[($entry.item.kind)]\t($entry.item.label)"
}
let selection = ($rows | str join "\n" | ^fzf --reverse --no-sort --border rounded
    --info inline --pointer "→" --prompt "Session > "
    --header "Sessions and projects · previous session first"
    --delimiter "\t" --with-nth "2.." | complete)
if $selection.exit_code in [1 130] { exit 0 }
if $selection.exit_code != 0 {
    error make {msg: $selection.stderr}
}
if ($selection.stdout | str trim | is-empty) { exit 0 }
let index = $selection.stdout | split row "\t" | first | into int
let target = $options | get $index
if $target.name == $current_session { exit 0 }

# Native switching avoids plugin aliases and shell-parsed argument strings.
# Supply a cwd only when creating a directory's session, preserving existing work.
if not $inside_zellij {
    if $target.cwd != null and $target.name not-in $sessions {
        exec zellij attach $target.name --create options --default-cwd $target.cwd
    } else {
        exec zellij attach $target.name --create
    }
}
let result = if $target.cwd != null and $target.name not-in $sessions {
    ^zellij action switch-session $target.name --cwd $target.cwd | complete
} else {
    ^zellij action switch-session $target.name | complete
}
if $result.exit_code != 0 {
    error make {msg: $result.stderr}
}
if $current_session != "" {
    mkdir ($state_file | path dirname)
    $current_session | save --force $state_file
}
