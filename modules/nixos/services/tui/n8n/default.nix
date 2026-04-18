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
      }
      // lib.optionalAttrs config.mine.mihomo.enable {
        HTTP_PROXY = "http://127.0.0.1:${toString config.mine.mihomo.port}";
        HTTPS_PROXY = "http://127.0.0.1:${toString config.mine.mihomo.port}";
        NO_PROXY = "localhost,127.0.0.1,::1";
      };
    };
  };
}
