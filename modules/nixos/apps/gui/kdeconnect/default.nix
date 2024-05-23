{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "kdeconnect";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "phone"
      "interactive"
    ];
  };

  config = mkIf cfg.enable { programs.kdeconnect.enable = true; };
}
