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
  name = "lf";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    xdg.configFile."lf/icons".source = ./icons;
    programs.lf = {
      enable = false;
      commands = {
        mkdir = ''
          ''${{
            printf "Directory Name: "
            read DIR
            mkdir -p $DIR
          }}
        '';
        trash = "\$${lib.getExe pkgs.trashy} \"$fx\"";
      };
      settings = {
        number = true;
        preview = true;
        hidden = true;
        drawbox = true;
        icons = true;
        ignorecase = true;
      };
      keybindings = {
        "<enter>" = "open";
        o = "mkdir";
        D = "trash";
      };
      previewer.source = lib.getExe' pkgs.ctpv "ctpv";
    };
  };
}
