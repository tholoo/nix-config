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
  name = "ripgrep";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-utils"
    ];
  };

  config = mkIf cfg.enable {
    programs.ripgrep = {
      enable = true;
      arguments = [
        "--smart-case"
        "--glob=!.git/*"
      ];
    };
  };
}
