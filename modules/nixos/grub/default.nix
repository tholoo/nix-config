{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "grub";
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
    boot.loader = {
      grub = {
        enable = true;
        configurationLimit = 30;
        efiSupport = true;
        efiInstallAsRemovable = true;
      };
    };
  };
}
