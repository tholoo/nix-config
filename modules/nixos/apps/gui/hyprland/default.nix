{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "hyprland";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "window-manager"
    ];
  };

  config = mkIf cfg.enable {
    programs = {
      hyprland.enable = true;
    };
  };
}
