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
    xdg.portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-termfilechooser
      ];
      config = {
        common = {
          default = [
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "xdg-desktop-portal-termfilechooser" ];
        };
        hyprland = {
          default = [
            "gtk"
            "hyprland"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "xdg-desktop-portal-termfilechooser" ];
        };
      };
    };
    environment.systemPackages = with pkgs; [
      xdg-desktop-portal-termfilechooser
      qt6Packages.qt6ct
      libadwaita
      adwaita-icon-theme
      gtk4
    ];
    environment.sessionVariables = {
      GTK_USE_PORTAL = 1;
      GDK_DEBUG = "portals";
      XDG_CURRENT_DESKTOP = "Hyprland";
      QT_QPA_PLATFORMTHEME = "qt5ct:qt6ct";
    };
  };
}
