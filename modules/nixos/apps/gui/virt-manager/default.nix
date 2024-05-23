{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "virt-manager";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "emulation"
    ];
  };

  config = mkIf cfg.enable { programs.virt-manager.enable = true; };
}
