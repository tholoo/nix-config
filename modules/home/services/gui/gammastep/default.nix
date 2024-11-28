{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "gammastep";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "screen"
      "light"
    ];
  };

  config = mkIf cfg.enable {
    services.${name} = {
      enable = true;
      provider = "manual";
      dawnTime = "6:00-7:45";
      duskTime = "18:35-20:15";
      settings = {
        general = {
          adjustment-method = "wayland";
        };
      };
    };
  };
}
