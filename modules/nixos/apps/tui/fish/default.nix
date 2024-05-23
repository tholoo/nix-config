{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "fish";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
    ];
  };

  config = mkIf cfg.enable { programs.fish.enable = true; };
}
