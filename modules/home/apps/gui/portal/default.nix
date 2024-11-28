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
        # mine.xdg-desktop-portal-termfilechooser
        pkgs.xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
        # xdg-desktop-portal-kde
        # xdg-desktop-portal-wlr
        # xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          default = [
            "Hyprland"
            "gtk"
            # "qt5"
            # "qtwayland"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "xdg-desktop-portal-termfilechooser" ];
          # "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
        hyprland.default = [
          "gtk"
          "hyprland"
        ];
      };
    };
    gtk = {
      enable = true;
      theme = {
        package = pkgs.arc-theme;
        name = "Arc";
      };
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
