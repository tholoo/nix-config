{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "plymouth";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "boot"
      "graphics"
    ];
  };

  config = mkIf cfg.enable {
    boot.plymouth = {
      enable = true;
      themePackages = with pkgs.mine; [ plymouth_watch_dogs ];
      theme = "watch_dogs";
    };
  };
}
