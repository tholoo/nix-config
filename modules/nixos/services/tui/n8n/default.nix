{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "n8n";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "service"
      "automation"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    services.n8n = {
      enable = true;
      openFirewall = true;
      environment = {
        N8N_SECURE_COOKIE = false;
      };
    };
  };
}
