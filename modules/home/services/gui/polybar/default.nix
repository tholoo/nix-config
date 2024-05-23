{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "polybar";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "gui-bar"
    ];
  };

  config = mkIf cfg.enable {
    services.polybar = {
      enable = true;
      script = "polybar bar &";
    };
  };
}
