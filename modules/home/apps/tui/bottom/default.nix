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
  name = "bottom";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-utils"
    ];
  };

  config = mkIf cfg.enable {
    programs.bottom = {
      enable = true;
      settings = {
        flags = {
          temperature_type = "c";
        };
        colors = {
          low_battery_color = "red";
        };
      };
    };
  };
}
