{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "security";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    security = {
      polkit.enable = true;
      rtkit.enable = true;
      pam.services.swaylock = {
        text = "auth include login";
      };
      pam.services.hyprlock = { };
    };
  };
}
