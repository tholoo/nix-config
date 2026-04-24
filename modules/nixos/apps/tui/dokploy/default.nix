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
    age.secrets.dokploy-db-password.file = inputs.self + /secrets/dokploy/dokploy-db-password.age;

    virtualisation.docker = {
      enable = true;
      daemon.settings.live-restore = false;
    };

    services.dokploy = {
      enable = true;
      port = null; # disable port 3000
      database.passwordFile = config.age.secrets.dokploy-db-password.path;
    };
  };
}
