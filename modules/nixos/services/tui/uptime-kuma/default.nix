{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "uptime-kuma";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      appriseSupport = true;
      settings = {
        HOST = "0.0.0.0";
        PORT = "3001";
      };
    };

    networking.firewall.allowedTCPPorts = [ 3001 ];
  };
}
