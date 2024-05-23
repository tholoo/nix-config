{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "mpris-proxy";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "bluetooth"
    ];
  };

  config = mkIf cfg.enable {
    # use headphone buttons to control volume
    services.mpris-proxy.enable = true;
  };
}
