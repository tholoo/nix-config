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
  name = "kanshi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "monitor"
    ];
  };

  config = mkIf cfg.enable {
    services.kanshi = {
      enable = true;
      systemdTarget = "hyprland-session.target";

      settings = [
        {
          profile = {
            name = "undocked";
            outputs = [ { criteria = "eDP-1"; } ];
          };
        }
        {
          profile = {
            name = "docked";
            outputs = [
              {
                criteria = "eDP-1";
                position = "1920,0";
              }
              {
                criteria = "HDMI-A-1";
                position = "0,0";
              }
            ];
          };
        }
      ];
    };
  };
}
