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
  name = "darkman";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "theme"
    ];
  };

  config = mkIf cfg.enable {
    # auto dark mode
    services.darkman = {
      enable = true;
      settings = {
        usegeoclue = true;
      };
    };
  };
}
