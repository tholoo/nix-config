{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "wluma";
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
    services.wluma = {
      enable = true;
    };
  };
}
