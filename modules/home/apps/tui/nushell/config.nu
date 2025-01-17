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
    | get -i 0.expansion

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

# Shadow the ls command so that you always have the sort type you want
def ls [path?] {
  if $path == null {
    core-ls . | sort-by type name -i
  } else {
    core-ls $path | sort-by type name -i
  }
}

def la [path?] {
  if $path == null {
    core-ls --all . | sort-by type name -i
  } else {
    core-ls --all $path | sort-by type name -i
  }
}

def laa [path?] {
  if $path == null {
    core-ls -la -d . | sort-by type name -i
  } else {
    core-ls -la -d $path | sort-by type name -i
  }
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
 }
