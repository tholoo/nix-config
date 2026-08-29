let zoxide_completer = {|spans|
    $spans | skip 1 | zoxide query -l ...$in | lines | where {|x| $x != $env.PWD}
}

let carapace_completer = {|spans: list<string>|
    carapace $spans.0 nushell ...$spans
    | from json
    | if ($in | default [] | where value == $"($spans | last)ERR" | is-empty) { $in } else { null }
}

let fish_completer = {|spans|
    fish --command $'complete "--do-complete=($spans | str join " ")"'
    | from tsv --flexible --noheaders --no-infer
    | rename value description
}

let external_completer = {|spans|
    let expanded_alias = scope aliases
    | where name == $spans.0
    | get -o 0.expansion

    let spans = if $expanded_alias != null {
        $spans
        | skip 1
        | prepend ($expanded_alias | split row ' ' | take 1)
    } else {
        $spans
    }

    match $spans.0 {
        # carapace completions are incorrect for nu
        nu => $fish_completer
        # fish completes commits and branch names in a nicer way
        git => $fish_completer
        # carapace doesn't have completions for asdf
        asdf => $fish_completer
        # use zoxide completions for zoxide commands
        __zoxide_z | __zoxide_zi => $zoxide_completer
        _ => $carapace_completer
    } | do $in $spans
}

alias core-ls = ls;

# List the filenames, sizes, and modification times of items in a directory.
def ls [
    --all (-a),         # Show hidden files
    --long (-l),        # Get all available columns for each entry (slower; columns are platform-dependent)
    --short-names (-s), # Only print the file names, and not the path
    --full-paths (-f),  # display paths as absolute paths
    --du (-d),          # Display the apparent directory size ("disk usage") in place of the directory metadata size
    --directory (-D),   # List the specified directory itself instead of its contents
    --mime-type (-m),   # Show mime-type in type column instead of 'file' (based on filenames only; files' contents are not examined)
    --threads (-t),     # Use multiple threads to list contents. Output will be non-deterministic.
    ...pattern: glob,   # The glob pattern to use.
]: [ nothing -> table ] {
    let pattern = if ($pattern | is-empty) { [ '.' ] } else { $pattern }
    (core-ls
        --all=$all
        --long=$long
        --short-names=$short_names
        --full-paths=$full_paths
        --du=$du
        --directory=$directory
        --mime-type=$mime_type
        --threads=$threads
        ...$pattern
    ) | sort-by type name -i | table
}


def la [
    --long (-l),        # Get all available columns for each entry (slower; columns are platform-dependent)
    --short-names (-s), # Only print the file names, and not the path
    --full-paths (-f),  # display paths as absolute paths
    --du (-d),          # Display the apparent directory size ("disk usage") in place of the directory metadata size
    --directory (-D),   # List the specified directory itself instead of its contents
    --mime-type (-m),   # Show mime-type in type column instead of 'file' (based on filenames only; files' contents are not examined)
    --threads (-t),     # Use multiple threads to list contents. Output will be non-deterministic.
    ...pattern: glob,   # The glob pattern to use.
]: [ nothing -> table ] {
    let pattern = if ($pattern | is-empty) { [ '.' ] } else { $pattern }
    (core-ls
        --all
        --long=$long
        --short-names=$short_names
        --full-paths=$full_paths
        --du=$du
        --directory=$directory
        --mime-type=$mime_type
        --threads=$threads
        ...$pattern
    ) | sort-by type name -i | table
}

# zellij

def start_zellij [] {
  if 'ZELLIJ' not-in ($env | columns) {
      zellij attach default --create options --default-cwd $env.PWD
  }
}

start_zellij

def zellij-report-cwd-to-terminal [] {
    if ("ZELLIJ" in $env) {
        let host = (try { hostname | str trim } catch { "" })
        let cwd = ($env.PWD | url encode)
        print -n $"(ansi osc)7;file://($host)($cwd)(ansi st)"
    }
}


# https://github.com/nushell/nu_scripts/blob/main/modules/data_extraction/ultimate_extractor.nu
# Function to extract archives with different extensions.


let abbreviations = {
  "k": "kubectl",
  "kns": "kubens"
  "ktx": "kubectx"
  "g": "git"
}

$env.config = {
   show_banner: false,
   edit_mode: helix,
   cursor_shape: {
      helix_normal: block
      helix_select: underscore
      helix_insert: line
   }
   completions: {
   external: {
      enable: true
      completer: $external_completer
   }
  }

  menus: [
    {
        name: abbr_menu
        only_buffer_difference: false
        marker: none
        type: {
            layout: columnar
            columns: 1
            col_width: 20
            col_padding: 2
        }
        style: {
            text: green
            selected_text: green_reverse
            description_text: yellow
        }
        source: { |buffer, position|
            let match = $abbreviations | columns | where $it == $buffer
            if ($match | is-empty) {
                { value: $buffer }
            } else {
                { value: ($abbreviations | get $match.0) }
            }
        }
    }
  ]


  # https://www.nushell.sh/book/line_editor.html#customizing-your-prompt
  # https://github.com/selfagency/nushell-config/blob/main/keybindings.nu
  keybindings: [
    {
        name: paste_bash_multiline
        modifier: alt
        keycode: char_v
        mode: [emacs, helix_normal, helix_insert, helix_select]
        event: { send: ExecuteHostCommand 
            cmd: r#'commandline edit (
                    wl-paste
                    | str replace -ar '\\(?=\r?\n)' '' 
                    | $"\(($in))"
                )'#
        }
    },
    {
      name: fuzzy_file_dir_completion
      modifier: control
      keycode: char_t
      mode: [emacs, helix_normal, helix_insert, helix_select]
      event: [
        {
          send: ExecuteHostCommand
          cmd: "commandline edit --insert (
            fzf --scheme=path
              --ansi
              --height=40%
              --reverse
              --walker=file,dir,follow,hidden
              --multi
            | lines 
            | str join ' '
          )"
        }
      ]
    }
    {
      name: abbr_menu_enter
      modifier: none
      keycode: enter
      mode: [emacs, helix_normal, helix_insert, helix_select]
      event: [
          { send: menu name: abbr_menu }
          { send: enter }
      ]
    }
    {
      name: abbr_menu_space
      modifier: none
      keycode: space
      mode: [emacs, helix_normal, helix_insert, helix_select]
      event: [
          { send: menu name: abbr_menu }
          { edit: insertchar value: ' '}
      ]
    },
  ]

    hooks: {
        env_change: {
            PWD: [
                { |before, after| zellij-report-cwd-to-terminal }
                { |before, after| zellij-update-tabname-git }
            ]
        }
        pre_execution: [
            {|| zellij-update-tabname-ssh-or-git }
        ]
        pre_prompt: [
            {||
                zellij-report-cwd-to-terminal
                if ("ZELLIJ" in $env) {
                    let initialized = (zellij-cache-get "initialized")
                    let needs_restore = (zellij-cache-get "needs_restore")
                    if ($initialized != "1") or ($needs_restore == "1") {
                        zellij-update-tabname-git
                    }
                }
            }
        ]
    } }

def e_completer [] {
    core-ls -la | get name
}

export def e [path: string@e_completer = "."] {
    env $env.EDITOR $path
}

export def shell [...pkgs: string] {
  let nix_pkgs = $pkgs | each { |pkg| $"nixpkgs#($pkg)" }
  ^nix shell ...$nix_pkgs
}

export def --env mkcd [name: path] {
  mkdir $name
  cd $name
}

export def psgrep [query: string] {
    ps
    | each {|e| if ($e.name | str contains --ignore-case $query) { $e }}
    | compact
}

export def windows [] {
    ^sudo efibootmgr -n 0000
    if $env.LAST_EXIT_CODE != 0 {
        error make { msg: "failed to set one-shot Windows boot entry" }
    }
    ^sudo reboot
}

def zellij-cache-dir [] {
    let session_name = (
        $env
        | get -o ZELLIJ_SESSION_NAME
        | default "unknown-session"
        | into string
        | str replace -ar '[^A-Za-z0-9_.-]' '_'
    )
    let pane_id = (
        $env
        | get -o ZELLIJ_PANE_ID
        | default "unknown-pane"
        | into string
        | str replace -ar '[^A-Za-z0-9_.-]' '_'
    )

    ["/tmp" $"nushell-zellij-tabname-($session_name)-($pane_id)"] | path join
}

def zellij-cache-get [key: string] {
    let path = ([(zellij-cache-dir) $key] | path join)
    if ($path | path exists) {
        open --raw $path | str trim
    } else {
        ""
    }
}

def zellij-cache-set [key: string, value: string] {
    let dir = (zellij-cache-dir)
    mkdir $dir
    $value | save --force ([$dir $key] | path join)
}

def zellij-current-pane-tab-id [] {
    if ("ZELLIJ_PANE_ID" not-in $env) {
        return null
    }

    let current_pane_id = ($env.ZELLIJ_PANE_ID | into string)
    let panes = (try {
        zellij action list-panes --json --all --tab | from json
    } catch {
        []
    })

    let current_pane = (
        $panes
        | where {|pane|
            let is_plugin = ($pane | get -o is_plugin | default false)
            let raw_pane_id = ($pane | get -o pane_id | default ($pane | get -o id))
            let pane_id = ($raw_pane_id | default "" | into string)
            let is_current_pane = (
                ($pane_id == $current_pane_id)
                or ($pane_id == $"terminal_($current_pane_id)")
                or ($"terminal_($pane_id)" == $current_pane_id)
            )

            (not $is_plugin) and $is_current_pane
        }
        | get -o 0
    )

    if $current_pane == null {
        return null
    }

    let tab_id = ($current_pane | get -o tab_id)
    if $tab_id != null {
        return $tab_id
    }

    let tab = ($current_pane | get -o tab)
    if $tab != null {
        let nested_id = ($tab | get -o id)
        if $nested_id != null {
            return $nested_id
        }

        let nested_tab_id = ($tab | get -o tab_id)
        if $nested_tab_id != null {
            return $nested_tab_id
        }
    }

    null
}

def zellij-rename-current-pane-tab [name: string] {
    if ("ZELLIJ" not-in $env) {
        return
    }

    # Session names and pane IDs are reused after Zellij restarts, so neither
    # the tab ID nor the last applied name is safe to persist in /tmp.
    let tab_id = (zellij-current-pane-tab-id)
    if $tab_id != null {
        zellij action rename-tab-by-id ($tab_id | into string) $name err> /dev/null
    } else {
        zellij action rename-tab $name err> /dev/null
    }
}

def zellij-update-tabname-git [] {
    if ("ZELLIJ" in $env) {
        let current_dir = pwd;
        
        mut tab_name = if ($current_dir == $env.HOME) {
            "~"
        } else {
            ($current_dir | path parse | get stem)
        };

        let in_git = (try { git rev-parse --is-inside-work-tree err> /dev/null } catch { "false" });
        if ($in_git | into bool) {
            # Get the git superproject root if available.
            let git_root_super = (try { git rev-parse --show-superproject-working-tree err> /dev/null } catch { "" });
            let git_root = if ($git_root_super == "") {
                (try { git rev-parse --show-toplevel err> /dev/null } catch { "" })
            } else {
                $git_root_super
            };

            # If current directory isn’t the same as the git root, prepend the repo’s basename.
            if (($git_root | str lowercase) != ($current_dir | str lowercase)) {
                let repo_name = ($git_root | path parse | get stem);
                let subpath = ($current_dir | str replace $"($git_root)/" "");
                $tab_name = $"($repo_name):($subpath)"
            }
        }

        # Update the zellij tab name.
        zellij-rename-current-pane-tab $tab_name
        zellij-cache-set "initialized" "1"
        zellij-cache-set "needs_restore" "0"
    }
}

def extract-ssh-target [cmd: string] {
    let parts = (
        $cmd
        | str trim
        | split row --regex '\s+'
        | where {|x| $x != "" }
    )

    if ($parts | is-empty) {
        return null
    }

    let ssh_names = ["ssh", "autossh", "mosh"]
    let wrappers = [
        "sudo" "doas" "env" "nohup" "time" "command" "exec"
        "gg" "dg" "direct" "proxychains" "proxychains4" "tsocks"
    ]

    # Walk past any wrapper prefix (sudo, gg, dg, direct, proxychains, …) plus their
    # flags / KEY=val args to find the *program* actually being run. This
    # stops `man ssh foo`, `grep -r ssh dir/`, etc. from being matched, while
    # still recognising `gg ssh host`, `gg -n node ssh host`, `sudo ssh host`.
    mut prog_idx = 0
    let n = ($parts | length)
    while $prog_idx < $n {
        let t = ($parts | get $prog_idx)

        if $t in $wrappers {
            $prog_idx = $prog_idx + 1
            continue
        }

        # A flag is only meaningful after we've already skipped a wrapper —
        # otherwise the first token would just be a non-program flag.
        if $prog_idx > 0 and ($t | str starts-with "-") {
            $prog_idx = $prog_idx + 1
            # If the next token isn't ssh-like / a flag / a wrapper / KEY=val,
            # assume it's this flag's value and skip it too. (Best-effort:
            # the cost of guessing wrong is just missing a tab rename.)
            if $prog_idx < $n {
                let nxt = ($parts | get $prog_idx)
                let nxt_is_ssh = (
                    ($nxt in $ssh_names)
                    or ($ssh_names | any {|m| $nxt | str ends-with $"/($m)" })
                )
                let nxt_is_flag = ($nxt | str starts-with "-")
                let nxt_is_wrap = ($nxt in $wrappers)
                let nxt_is_assign = ($nxt =~ '^[A-Za-z_][A-Za-z_0-9]*=')
                if (not $nxt_is_ssh) and (not $nxt_is_flag) and (not $nxt_is_wrap) and (not $nxt_is_assign) {
                    $prog_idx = $prog_idx + 1
                }
            }
            continue
        }

        if ($t =~ '^[A-Za-z_][A-Za-z_0-9]*=') {
            $prog_idx = $prog_idx + 1
            continue
        }

        break
    }

    if $prog_idx >= $n {
        return null
    }

    let prog = ($parts | get $prog_idx)
    let is_ssh = (
        ($prog in $ssh_names)
        or ($ssh_names | any {|m| $prog | str ends-with $"/($m)" })
    )
    if not $is_ssh {
        return null
    }

    mut i = $prog_idx + 1
    while $i < ($parts | length) {
        let tok = ($parts | get $i)

        # options that consume a value
        if $tok in [
            "-B" "-b" "-c" "-D" "-E" "-e" "-F" "-I" "-i" "-J" "-L" "-l"
            "-m" "-O" "-o" "-p" "-Q" "-R" "-S" "-W" "-w"
        ] {
            $i = $i + 2
            continue
        }

        # flags without value
        if ($tok | str starts-with "-") {
            $i = $i + 1
            continue
        }

        let dest = $tok

        let no_scheme = if ($dest | str starts-with "ssh://") {
            $dest | str replace "ssh://" ""
        } else {
            $dest
        }

        let no_user = if ($no_scheme | str contains "@") {
            $no_scheme | split row "@" | last
        } else {
            $no_scheme
        }

        if ($no_user | str starts-with "[") {
            let host = ($no_user | parse --regex '^\[(?<host>.+)\](?::(?<port>\d+))?$')
            if not ($host | is-empty) {
                return ($host | get 0.host)
            }
            return $no_user
        }

        let parsed = ($no_user | parse --regex '^(?<host>[^:]+)(?::(?<port>\d+))?$')
        if not ($parsed | is-empty) {
            return ($parsed | get 0.host)
        }

        return $no_user
    }

    null
}

def zellij-update-tabname-ssh-or-git [] {
    if ("ZELLIJ" not-in $env) {
        return
    }

    # Only act if the user is actually running an ssh-like command. The
    # PWD env_change hook + pre_prompt hook already keep the tab name in sync
    # with the working directory, so non-ssh commands need nothing here.
    let ssh_target = (extract-ssh-target (commandline))
    if $ssh_target != null {
        zellij-rename-current-pane-tab $ssh_target
        zellij-cache-set "needs_restore" "1"
    }
}

export def my_ip [
    --short (-s)
] {
    if $short {
        sys net
        | flatten ip
        | get ip.address
        | where {|it| $it =~ "192.168"}
    } else {
        sys net
        | flatten ip
        | where {|it| $it.ip.address =~ "192.168"}
    }
}

# ─── ai: claude-code wrappers for nu pipelines ──────────────────────────
# Subcommands either bundle context you'd otherwise type by hand, or exploit
# nu's structured data (table in / table out). All of them call `claude -p`.

def _ai-confirm [msg: string]: nothing -> bool {
    let answer = (input $"($msg) [y/N] ")
    ($answer | str lowercase | str trim) in ["y" "yes"]
}

def _ai-confirm-strict [msg: string]: nothing -> bool {
    let answer = (input $"($msg) \(type 'yes' to proceed\) ")
    ($answer | str trim) == "yes"
}

def _ai-strip-fences []: string -> string {
    $in
    | str replace -ar '^```[a-zA-Z]*\n?' ''
    | str replace -ar '\n?```$' ''
    | str trim
}

def _ai-cap [rows: any, cap: int]: nothing -> bool {
    let n = ($rows | length)
    if $n > $cap {
        print $"warn: ($n) rows means ($n) separate API calls."
        _ai-confirm "continue?"
    } else { true }
}

def _ai-model-args [haiku: bool]: nothing -> list<string> {
    if $haiku { ["--model" "haiku"] } else { [] }
}

def ai [] {
    print "Usage:"
    print "  ai ask <prompt>           claude -p, optionally with piped stdin"
    print "  ai nu <request>           english → nu pipeline (always confirms)"
    print "  ai annotate <prompt>      add a column per row (--field, --cap)"
    print "  ai extract <fields>       prose stdin → nu table"
    print "  ai filter <criterion>     semantic where on rows (--cap)"
    print "  ai pick <criterion>       pick the single best-matching row"
    print ""
    print "Common flags: --haiku (cheap+fast), --dry-run (print payload, don't call API)"
}

# ai ask <prompt> — claude -p with stdin forwarded as context
def "ai ask" [prompt: string, --haiku, --dry-run]: any -> any {
    let stdin = $in
    let stdin_str = if ($stdin == null) {
        null
    } else if (($stdin | describe) | str starts-with "string") {
        $stdin
    } else {
        $stdin | to json
    }
    if $dry_run {
        print $"prompt: ($prompt)"
        if $stdin_str != null { print $"stdin: ($stdin_str)" }
        return
    }
    let model_args = (_ai-model-args $haiku)
    if $stdin_str == null {
        ^claude ...$model_args -p $prompt
    } else {
        $stdin_str | ^claude ...$model_args -p $prompt
    }
}

# ai nu <request> — translate english to a nu pipeline. Always confirms.
def "ai nu" [
    request: string
    --yes (-y)   # skip prompt for non-dangerous pipelines (still strict-confirms dangerous ones)
    --haiku
    --dry-run    # never execute, just print the pipeline
] {
    let model_args = (_ai-model-args $haiku)
    let prompt = $"Translate this request into a single nushell pipeline. Output ONLY the pipeline — no fences, no prose, no comments. Request: ($request)"
    let cmd = (^claude ...$model_args -p $prompt | _ai-strip-fences)
    print $"> ($cmd)"
    if $dry_run { return }

    let hard_block = ['rm -rf /' '--no-preserve-root' 'mkfs' 'dd if=' 'of=/dev/sd' 'of=/dev/nvme']
    for tok in $hard_block {
        if ($cmd | str contains $tok) {
            print $"refusing: pipeline contains '($tok)'"
            return
        }
    }

    # nu's redirect operators (not bash's bare `>`, which in nu is comparison)
    let danger = ['rm ' 'mv ' '--force' 'out>' 'o>' 'err>' 'e>' '^curl' '^wget' ' curl ' ' wget ' 'sudo' 'chmod ' 'chown ' 'http://' 'https://']
    let is_danger = ($danger | any {|t| $cmd | str contains $t })

    let approved = if $is_danger {
        print "this pipeline writes, deletes, hits the network, or escalates."
        _ai-confirm-strict "approve?"
    } else if $yes {
        true
    } else {
        _ai-confirm "run?"
    }

    if $approved { nu -c $cmd }
}

# stdin | ai annotate <prompt> — add a column per row, in parallel
def "ai annotate" [
    prompt: string
    --field: string = "ai"     # column name to insert
    --cap: int = 50            # confirm if input has more than this many rows
    --threads: int = 8         # parallel API calls
    --haiku
    --dry-run
]: list -> list {
    let rows = $in
    if not (_ai-cap $rows $cap) { return $rows }
    let model_args = (_ai-model-args $haiku)

    $rows
    | par-each --threads $threads {|r|
        let payload = $"($prompt)\n\nReply with one short line, no preamble.\n\n--- ROW ---\n($r | to json)"
        let answer = if $dry_run { "<dry-run>" } else { ^claude ...$model_args -p $payload | str trim }
        $r | insert $field $answer
    }
    | collect
}

# stdin | ai extract <fields> — produce a nu table from prose stdin
def "ai extract" [
    fields: string   # e.g. "vendor, date, amount" or "name, email, role"
    --haiku
    --dry-run
]: any -> any {
    let stdin = $in
    let stdin_str = if (($stdin | describe) | str starts-with "string") {
        $stdin
    } else {
        $stdin | to json
    }
    let prompt = $"Extract the following fields from the input as a JSON array of objects. Fields: ($fields). Output ONLY a JSON array, no prose, no fences."
    if $dry_run {
        print $"prompt: ($prompt)"
        print $"stdin: ($stdin_str)"
        return
    }
    let model_args = (_ai-model-args $haiku)
    $stdin_str | ^claude ...$model_args -p $prompt | _ai-strip-fences | from json
}

# stdin | ai filter <criterion> — semantic where on rows, in parallel
def "ai filter" [
    criterion: string
    --cap: int = 50
    --threads: int = 8
    --haiku
    --dry-run
]: list -> list {
    let rows = $in
    if not (_ai-cap $rows $cap) { return $rows }
    let model_args = (_ai-model-args $haiku)

    $rows
    | par-each --threads $threads {|r|
        let keep = if $dry_run {
            true
        } else {
            let payload = $"Does this row match the criterion?\nCriterion: ($criterion)\nRow: ($r | to json)\nReply with exactly 'yes' or 'no', nothing else."
            (^claude ...$model_args -p $payload | str trim | str lowercase | str starts-with "yes")
        }
        { __keep: $keep, __row: $r }
    }
    | collect
    | where __keep
    | get __row
}

# stdin | ai pick <criterion> — single row best matching the criterion
def "ai pick" [
    criterion: string
    --haiku
    --dry-run
]: list -> any {
    let rows = $in
    let payload = $"From the JSON array of rows below, pick the single row that best matches the criterion: ($criterion). Reply with ONLY the integer index \(0-based\), nothing else.\n\n--- ROWS ---\n($rows | to json)"
    if $dry_run {
        print $payload
        return
    }
    let model_args = (_ai-model-args $haiku)
    let idx = (^claude ...$model_args -p $payload | str trim | into int)
    $rows | get $idx
}

zellij-update-tabname-git
