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
  name = "termfilechooser";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    environment.etc."xdg/xdg-desktop-portal-termfilechooser/config".text = ''
      [filechooser]
      cmd=${./yazi-wrapper.sh}
    '';

    systemd.user.services.xdg-desktop-portal-termfilechooser = {
      serviceConfig.ExecStart = [
        ""
        "${pkgs.mine.xdg-desktop-portal-termfilechooser}/libexec/xdg-desktop-portal-termfilechooser --loglevel=ERROR"
      ];
    };
  };
}
