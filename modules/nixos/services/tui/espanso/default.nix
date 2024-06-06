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
  name = "espanso";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    services.espanso = {
      enable = true;
      package = pkgs.espanso-wayland;
    };
  };
}
