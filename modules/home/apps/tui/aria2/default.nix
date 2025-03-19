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
  name = "aria2";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "download"
    ];
  };

  config = mkIf cfg.enable {
    programs.aria2 = {
      enable = true;
    };
  };
}
