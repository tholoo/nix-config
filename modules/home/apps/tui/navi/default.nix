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
  name = "navi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "help"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
    };
  };
}
