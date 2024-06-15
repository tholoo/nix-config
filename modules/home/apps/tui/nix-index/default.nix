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
  name = "nix-index";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "extra"
      "nix"
    ];
  };

  config = mkIf cfg.enable { programs.nix-index.enable = true; };
}
