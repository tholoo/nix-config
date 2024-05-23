{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "gui-misc";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "gui-misc"
    ];
  };

  config = mkIf cfg.enable { programs.light.enable = true; };
}
