#!/usr/bin/env nu

let LAST_SESSION = try { cat /tmp/zellij_last_session } catch { "" };

def fzf_window [] {
    fzf --reverse --no-sort --border "rounded" --info inline --pointer "→" --prompt "Session > " --header "Select session"
}

def set_last_session [session: string] {
    $session | save /tmp/zellij_last_session
}

def last_session [] {
    if ($LAST_SESSION != "") {
        "(1)\t[Session]\t" + $LAST_SESSION
    }
}

def sessions_list [] {
    if ($LAST_SESSION != "") {
        zellij list-sessions -s | grep -v $LAST_SESSION | awk '{ print "("NR")\t[Session]\t"$1 }'
    } else {
        zellij list-sessions -s | awk '{ print "("NR")\t[Session]\t"$1 }'
    }
}

def project_list [] {
    let list = zoxide query --list | sed $"s|^($env.HOME)|~|"
    $list | tr --truncate-set1 " /" "\n" | awk '{ print "("NR")\t[Directory]\t"$1 }' 
}

def select_project [] {
    let options = $"(last_session)\n(sessions_list)\n(project_list)";
    let project_dir = ($options | fzf_window | str trim);
        if ( $project_dir == "" ) {
        exit
    } else {
        $project_dir
    }
}

def get_sanitized_selected [select:string] {
    $select | sed "s/^([0-9]*)\t[[^]]*]\t//"
}

def get_session_name [project_dir:string] {
    let directory = basename $project_dir;
    let session_name = $directory | tr ' .:' '_';
    $session_name
}

def transform_home_path [input] {
    $input | str replace -r "^~/" ($env.HOME + "/")
}

let selected = select_project;

if ( $selected == "" ) {
    exit 0
}

let cwd = get_sanitized_selected $selected
let session_name = get_session_name (transform_home_path $cwd)
let session = zellij list-sessions | grep $session_name
let current_session = zellij list-sessions -n | grep '(current)' | grep -o '^[^ ]*'
let is_current_session = zellij list-sessions -n | grep $"^($session_name) [Created" | grep "(current)"

set_last_session $current_session

# If we're inside of zellij, detach
if ("ZELLIJ" in $env) {
    if ($is_current_session == 0) {
        zellij pipe --plugin zellij-switch -- $"--session=($session_name) --cwd=($cwd)"
    }
} else {
    if ($session != "") {
        zellij attach $session_name -c
    }  else {
        zellij attach $session_name -c options --default-cwd $cwd
    }
}
