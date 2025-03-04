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
  name = "i3status-rust";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "gui-bar"
    ];
  };

  config = mkIf cfg.enable {
    programs.i3status-rust = {
      enable = false;
    };
  };
}
