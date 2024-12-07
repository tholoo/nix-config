{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "battery";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "laptop"
    ];
  };

  config = mkIf cfg.enable {
    services = {
      gvfs.enable = true;
      power-profiles-daemon.enable = true;
      upower.enable = true;
    };
  };
}
