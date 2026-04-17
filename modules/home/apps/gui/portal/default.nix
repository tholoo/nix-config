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
  name = "portal";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "wayland"
    ];
  };

  config = mkIf cfg.enable {
    home.pointerCursor = {
      gtk.enable = true;
      hyprcursor.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
    qt = {
      enable = true;
      platformTheme.name = "adwaita";
      style = {
        name = "adwaita-dark";
        package = pkgs.adwaita-qt6;
      };
    };
    gtk = {
      enable = true;
      font = {
        name = "DejaVu Sans";
        package = pkgs.dejavu_fonts;
      };
      theme = {
        package = pkgs.arc-theme;
        name = "Arc";
      };
      gtk4.theme = config.gtk.theme;
      iconTheme = {
        package = pkgs.papirus-icon-theme;
        name = "Papirus";
      };
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
      };
    };
  };
}
