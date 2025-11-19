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
  name = "vicinae";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "runner"
    ];
  };

  config = mkIf cfg.enable {
    programs.vicinae = {
      enable = true;
      systemd.enable = true;
      settings = {
        theme = {
          name = "vicinae-dark";
        };
      };
    };
  };
}
