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
      "gui"
    ];
  };

  config = mkIf cfg.enable {
    services.espanso = {
      enable = false;
      package = pkgs.espanso-wayland;
    };
  };
}
