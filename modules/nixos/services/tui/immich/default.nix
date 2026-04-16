{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "immich";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "personal"
      "media"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    services.immich = {
      enable = true;
      host = "0.0.0.0";
      openFirewall = true;
      accelerationDevices = null;
    };

    users.users.immich.extraGroups = [
      "video"
      "render"
    ];
  };
}
