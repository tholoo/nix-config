{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "home-manager";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "tui"
      "home"
      "config"
    ];
  };

  config = mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };
}
