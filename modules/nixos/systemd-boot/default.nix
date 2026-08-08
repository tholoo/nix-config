{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "systemd-boot";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "tui"
      "boot"
    ];
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.efibootmgr ];

    boot.loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 30;
      };
      efi.canTouchEfiVariables = true;
    };
  };
}
