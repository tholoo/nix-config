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
  name = "v2raya";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "proxy"
      "vpn"
    ];
  };

  config = mkIf cfg.enable { services.v2raya.enable = true; };
}
