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
  name = "kanshi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
    ];
  };

  config = mkIf cfg.enable { services.kanshi.enable = true; };
}
