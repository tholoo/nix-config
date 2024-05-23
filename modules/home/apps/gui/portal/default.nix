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
      extraPortals = with pkgs; [ xdg-desktop-portal-wlr ];
      config = {
        common = {
          default = [
            "sway"
            "gtk"
            "qt5"
            "qtwayland"
          ];
          "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
        };
      };
    };
  };
}
