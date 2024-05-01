{ pkgs, lib, ... }:
{
  xdg.configFile."lf/icons".source = ./icons;
  programs.lf = {
    enable = true;
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
    previewer.source = lib.getExe pkgs.ctpv;
  };
}
