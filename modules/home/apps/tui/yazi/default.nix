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
  name = "yazi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "f";
      plugins = with pkgs.yaziPlugins; {
        "glow" = glow;
        "smart-enter" = smart-enter;
        "mediainfo" = mediainfo;
      };
      keymap.mgr.prepend_keymap = [
        {
          on = [ "e" ];
          run = "open";
        }
        {
          on = [ "<Enter>" ];
          run = "plugin smart-enter";
          desc = "Enter the child directory, or open the file";
        }
        {
          on = [ "T" ];
          run = "plugin max-preview";
          desc = "Maximize preview";
        }
        {
          on = [ "<C-n>" ];
          # there is also ripdrag but it didn't seem to work
          run = ''
            shell '${lib.getExe pkgs.dragon-drop} -x -i -T "$1"' --confirm
          '';
          desc = "Drag & Drop";
        }
        {
          on = [ "y" ];
          run = [
            "yank"
            ''
              shell --confirm 'for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list'
            ''
          ];
        }
        {
          on = [ "<C-d>" ];
          run = [ "seek 5" ];
        }
        {
          on = [ "<C-u>" ];
          run = [ "seek -5" ];
        }
      ];
      settings = lib.mkOptionDefault {
        mgr = {
          ratio = [
            1
            3
            4
          ];
          show_hidden = true;
          sort_by = "mtime";
          sort_reverse = true;
          sort_dir_first = true;
          show_symlink = true;
          linemode = "size";
        };
        plugin = {
          prepend_previewers = [
            {
              name = "*.md";
              run = "glow";
            }
          ];
        };
      };
      # theme = builtins.fromTOML (builtins.readFile rose-pine);
    };
  };
}
