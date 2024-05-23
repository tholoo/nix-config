{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "feh";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "image"
      "media"
      "wallpaper"
    ];
  };

  config = mkIf cfg.enable {
    programs.feh = {
      enable = true;
    };
  };
}
