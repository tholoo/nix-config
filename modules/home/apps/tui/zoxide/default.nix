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
  name = "zoxide";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-interactive"
    ];
  };

  config = mkIf cfg.enable {
    programs.zoxide = {
      enable = true;
    };
  };
}
