{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "mount";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "usb"
    ];
  };

  config = mkIf cfg.enable {
    services.devmon.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
  };
}
