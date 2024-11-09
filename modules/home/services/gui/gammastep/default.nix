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
      latitude = 35.7219;
      longitude = 51.3347;
      settings = {
        general = {
          adjustment-method = "wayland";
        };
      };
    };
  };
}
