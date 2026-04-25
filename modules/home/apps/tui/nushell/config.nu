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
      zellij attach --create --index 0
  }
}

start_zellij


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
   edit_mode: vi,
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
        mode: [emacs, vi_normal, vi_insert]
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
      mode: [emacs, vi_normal, vi_insert]
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
      name: abbr_menu
      modifier: none
      keycode: enter
      mode: [emacs, vi_normal, vi_insert]
      event: [
          { send: menu name: abbr_menu }
          { send: enter }
      ]
    }
    {
      name: abbr_menu
      modifier: none
      keycode: space
      mode: [emacs, vi_normal, vi_insert]
      event: [
          { send: menu name: abbr_menu }
          { edit: insertchar value: ' '}
      ]
    },
  ]

    hooks: {
        env_change: {
            PWD: [
                { |before, after| zellij-update-tabname-git }
            ]
        }
        pre_execution: [
            {|| zellij-update-tabname-ssh-or-git }
        ]
        pre_prompt: [
            {||
                if ("ZELLIJ" in $env) {
                    zellij-update-tabname-git
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
            if (($git_root | str downcase) != ($current_dir | str downcase)) {
                let repo_name = ($git_root | path parse | get stem);
                let subpath = $current_dir | str replace $git_root "";
                $tab_name = $"($repo_name):($subpath)"
            }
        }

        # Update the zellij tab name.
        zellij action rename-tab $tab_name;
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

    let ssh_idx = (
        $parts
        | enumerate
        | where {|it|
            (
                ($it.item in $ssh_names)
                or ($ssh_names | any {|n| $it.item | str ends-with $"/($n)" })
            )
        }
        | get -o 0.index
    )

    if $ssh_idx == null {
        return null
    }

    mut i = $ssh_idx + 1
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

    let cmd = (commandline)

    let ssh_target = (extract-ssh-target $cmd)
    if $ssh_target != null {
        zellij action rename-tab $ssh_target
        return
    }

    zellij-update-tabname-git
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
    ($answer | str downcase | str trim) in ["y" "yes"]
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
            (^claude ...$model_args -p $payload | str trim | str downcase | str starts-with "yes")
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
