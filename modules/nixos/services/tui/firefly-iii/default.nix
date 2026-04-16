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
  name = "firefly-iii";

in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "service"
      "personal"
      "finance"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    services.firefly-iii = {
      enable = true;
      enableNginx = true;
      virtualHost = "firefly.local";
      settings = {
        APP_URL = "http://firefly.local";
        DB_CONNECTION = "sqlite";
        APP_KEY_FILE = config.age.secrets.firefly-app-key.path;
      };
    };

    services.nginx.virtualHosts."firefly.local" = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 8080;
        }
      ];
      forceSSL = false;
      enableACME = false;
    };

    networking.firewall.allowedTCPPorts = [ 8080 ];

    age.secrets.firefly-app-key = {
      file = inputs.self + /secrets/firefly/firefly-app-key.age;
      owner = "firefly-iii";
    };
  };
}
