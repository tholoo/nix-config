{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "stylix";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "gui"
      "theme"
    ];
  };

  config = mkIf cfg.enable {
    stylix.targets = {
      # hyprpanel manages its own theming
      hyprpanel.enable = false;
    };
  };
}
