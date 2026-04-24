{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "home-assistant";
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
      config.services.home-assistant.config.http.server_port
    ];

    services.home-assistant = {
      enable = true;
      extraComponents = [
        # Components required to complete the onboarding
        "analytics"
        "google_translate"
        "met"
        "radio_browser"
        "shopping_list"
        # Recommended for fast zlib compression
        # https://www.home-assistant.io/integrations/isal
        "isal"
        # Useful for Xiaomi devices added from the UI
        "xiaomi_miio"
      ];
      config = {
        # Includes dependencies for a basic setup
        # https://www.home-assistant.io/integrations/default_config/
        default_config = { };
        # Let UI-created automations/scripts/scenes work
        "automation ui" = "!include automations.yaml";
        "scene ui" = "!include scenes.yaml";
        "script ui" = "!include scripts.yaml";
      };
    };
    # Create the files Home Assistant expects, so startup does not fail
    systemd.tmpfiles.rules = [
      "f /var/lib/hass/automations.yaml 0644 hass hass"
      "f /var/lib/hass/scenes.yaml 0644 hass hass"
      "f /var/lib/hass/scripts.yaml 0644 hass hass"
    ];
  };
}
