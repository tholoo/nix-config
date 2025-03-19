{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "blueman";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "bluetooth"
    ];
  };

  config = mkIf cfg.enable { services.blueman.enable = true; };
}
