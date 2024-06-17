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
      package = pkgs.nushellFull;
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
            old-ls -a .
          } else {
            old-ls -a $path
          }
        }

        def laa [path?] {
          if $path == null {
            old-ls -la .
          } else {
            old-ls -la $path
          }
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
         }
         {
           name: fuzzy_history,
           modifier: control,
           keycode: char_r,
           mode: emacs,
           event: {
             send: executehostcommand,
             cmd: "commandline edit --replace (history | each { |it| $it.command } | uniq | reverse | str collect (char nl) | fzf --layout=reverse --height=40% -q (commandline) | decode utf-8 | str trim)"
           }
         }
         {
           name: fuzzy_file,
           modifier: control,
           keycode: char_t,
           mode: [emacs, vi_normal, vi_insert],
           event: {
             send: executehostcommand,
             cmd: "commandline edit --replace (fzf --layout=reverse)"
           }
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
