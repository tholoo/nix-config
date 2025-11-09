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
    }
 }

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

        let in_git = (try { git rev-parse --is-inside-work-tree } catch { "false" });
        if ($in_git | into bool) {
            # Get the git superproject root if available.
            let git_root_super = (try { git rev-parse --show-superproject-working-tree } catch { "" });
            let git_root = if ($git_root_super == "") {
                (try { git rev-parse --show-toplevel } catch { "" })
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


