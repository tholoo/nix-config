{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "proxy";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "vpn"
    ];
  };

  config = mkIf cfg.enable { services.resolved.enable = true; };
}
