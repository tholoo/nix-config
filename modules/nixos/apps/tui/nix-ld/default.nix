{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "nix-ld";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "compat"
    ];
  };

  config = mkIf cfg.enable {
    programs.nix-ld = {
      enable = true;
    };
  };
}
