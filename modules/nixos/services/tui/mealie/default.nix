{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "mealie";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "service"
      "automation"
      "server"
      "personal"
    ];
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      config.services.mealie.port
    ];

    services.mealie = {
      enable = true;
    };
  };
}
