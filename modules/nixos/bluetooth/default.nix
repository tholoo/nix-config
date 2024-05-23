{ config, lib, ... }:
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
    hardware = {
      bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
    };
  };
}
