{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "hyprpaper";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "service"
      "wallpaper"
    ];
  };

  config = mkIf cfg.enable {
    # progress bar
    services.hyprpaper = {
      enable = true;
      settings = {
        ipc = "on";
        splash = false;
        preload = [ "${inputs.self}/resources/wallpapers/wallhaven-car-swamp.png" ];
        wallpaper = [ ",${inputs.self}/resources/wallpapers/wallhaven-car-swamp.png" ];
      };
    };
  };
}
