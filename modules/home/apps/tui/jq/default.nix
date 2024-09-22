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
  name = "jq";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-utils"
    ];
  };

  config = mkIf cfg.enable {
    programs.jq = {
      enable = true;
    };
  };
}
