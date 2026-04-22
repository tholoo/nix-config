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
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
        xdg-desktop-portal-termfilechooser
      ];
      config = {
        common = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
        };
        hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
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
      # QT_QPA_PLATFORMTHEME managed by stylix
      TERMCMD = "ghostty --gtk-single-instance=false --class=dev.ghostty.chooser -e";
      # QT_QPA_PLATFORMTHEME = "xdgdesktopportal";
      # TDESKTOP_USE_GTK_FILE_DIALOG = 1;
    };
  };
}
