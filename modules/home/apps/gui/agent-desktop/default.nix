{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.mine.agent-desktop;
in
{
  options.mine.agent-desktop = lib.mine.mkEnable config { tags = [ ]; };
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.mine.agent-desktop ];
  };
}
