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

    server = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to configure grub for a server";
    };
  };

  config = mkIf cfg.enable {
    boot.loader = {
      efi.canTouchEfiVariables = if cfg.server then false else true;

      grub = {
        enable = true;
        configurationLimit = 30;
        efiSupport = true;
        efiInstallAsRemovable = if cfg.server then true else false;
        useOSProber = true;
        device = "nodev";

        # dedsec-theme = {
        #   enable = if cfg.server then false else true;
        #   style = "wannacry";
        #   icon = "color";
        #   resolution = "1080p";
        # };
      };
    };
  };
}
