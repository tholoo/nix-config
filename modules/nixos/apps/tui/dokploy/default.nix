{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "dokploy";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "deploy"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      daemon.settings.live-restore = false;
    };

    services.dokploy = {
      enable = true;
      port = null; # disable port 3000
    };
  };
}
