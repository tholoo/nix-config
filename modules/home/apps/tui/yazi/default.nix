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
      # The default 7-Zip package omits RAR decoding support.
      package = pkgs.yazi.override { _7zz = pkgs._7zz-rar; };
      shellWrapperName = "f";
      extraPackages = with pkgs; [
        glow
        ueberzugpp
      ];
      plugins = with pkgs.yaziPlugins; {
        "piper" = piper;
        "smart-enter" = smart-enter;
        "mediainfo" = mediainfo;
      };
      initLua = ''
        require("smart-enter"):setup { open_multi = true }
      '';
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
          run = "shell -- ${lib.getExe pkgs.dragon-drop} -x -i -T %h";
          desc = "Drag & Drop";
        }
        {
          on = [ "y" ];
          run = [
            ''
              shell -- for path in %s; do echo "file://$path"; done | ${lib.getExe' pkgs.wl-clipboard "wl-copy"} -t text/uri-list
            ''
            "yank"
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
        opener.open = [
          {
            run = ''for path in %s; do ${lib.getExe' pkgs.xdg-utils "xdg-open"} "$path"; done'';
            desc = "Open with default app";
            orphan = true;
          }
        ];
        open.prepend_rules = [
          {
            mime = "application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}";
            use = [
              "extract"
              "edit"
              "open"
              "reveal"
            ];
          }
          {
            url = "*";
            use = [
              "edit"
              "open"
              "reveal"
            ];
          }
        ];
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
              url = "*.md";
              run = "piper -- CLICOLOR_FORCE=1 glow -w=$w -s=dark \"$1\"";
            }
          ];
        };
      };
      # theme = builtins.fromTOML (builtins.readFile rose-pine);
    };
  };
}
