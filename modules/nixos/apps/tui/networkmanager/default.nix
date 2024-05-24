{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "networkmanager";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "network"
    ];
  };

  config = mkIf cfg.enable {
    networking = {
      # Pick only one of the below networking options.
      wireless.enable = false; # Enables wireless support via wpa_supplicant.
      networkmanager.enable = true; # Easiest to use and most distros use this by default.
      firewall.enable = true;
    };
  };
}
