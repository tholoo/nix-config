{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "nushell";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
    ];
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      # envFile.text = ''
      # '';
      configFile.text = ''
        let zoxide_completer = {|spans|
            $spans | skip 1 | zoxide query -l ...$in | lines | where {|x| $x != $env.PWD}
        }
        let carapace_completer = {|spans: list<string>|
            carapace $spans.0 nushell ...$spans
            | from json
            | if ($in | default [] | where value =~ '^-.*ERR$' | is-empty) { $in } else { null }
        }
        let fish_completer = {|spans|
            fish --command $'complete "--do-complete=($spans | str join " ")"'
            | $"value(char tab)description(char newline)" + $in
            | from tsv --flexible --no-infer
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

        def old-ls [path] {
          core-ls $path | sort-by type name -i
        }

        # Shadow the ls command so that you always have the sort type you want
        def ls [path?] {
          if $path == null {
            old-ls .
          } else {
            old-ls $path
          }
        }

        def la [path?] {
          if $path == null {
            core-ls -a . | sort-by type name -i
          } else {
            core-ls -a $path | sort-by type name -i
          }
        }

        def laa [path?] {
          if $path == null {
            core-ls -la . | sort-by type name -i
          } else {
            core-ls -la $path | sort-by type name -i
          }
        }

        let abbreviations = {
          "..": "cd .."
          "k": "kubectl"
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
              name: fuzzy_file,
              modifier: control,
              keycode: char_t,
              mode: [emacs, vi_normal, vi_insert],
              event: {
                send: executehostcommand,
                cmd: "commandline edit --replace (fzf --layout=reverse)"
              }
            },
            {
              name: abbr_menu
              modifier: none
              keycode: enter
              mode: [emacs, vi_normal, vi_insert]
              event: [
                  { send: menu name: abbr_menu }
                  { send: enter }
              ]
            },
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
      '';
      shellAliases = {
        # e = "$env.EDITOR";
        f = "${lib.getExe pkgs.yazi}";
        lg = lib.getExe pkgs.lazygit;
        # mysync = "${lib.getExe pkgs.rsync} --progress --partial --human-readable --archive --verbose --exclude-from='${./rsync-excludes.txt}'";
        fetch = lib.getExe pkgs.fastfetch;
        cat = "${lib.getExe pkgs.bat} -n";
      };
    };
  };
}
