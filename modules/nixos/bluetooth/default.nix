{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "bluetooth";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "bluetooth"
    ];
  };

  config = mkIf cfg.enable {
    hardware.firmware = [ pkgs.linux-firmware ];
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          MultiProfile = "multiple";
        };
      };
    };
  };
}
