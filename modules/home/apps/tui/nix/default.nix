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
  name = "nix";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # it provides the command `nom` works just like `nix`
      # with more detailed log output
      nix-output-monitor
      nix-prefetch-github
      nix-tree
      nh
      devenv
      manix
      nurl
    ];
  };
}
