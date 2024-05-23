{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "sound";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "sound"
      "interactive"
    ];
  };

  config = mkIf cfg.enable { sound.enable = true; };
}
