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
  name = "rio";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "terminal"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
      settings = {
        fonts = {
          size = 14;
          family = "FiraCode Nerd Font";
          extras = [ { family = "Vazir Code Hack"; } ];
        };
      };
    };
  };
}
