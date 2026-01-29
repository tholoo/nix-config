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
  name = "secrets";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "secrets"
    ];
  };

  config = mkIf cfg.enable {
    age.secrets = {
      singbox-domain.file = inputs.self + /secrets/singbox-domain.age;
      singbox-header-domain.file = inputs.self + /secrets/singbox-header-domain.age;
      singbox-uuid.file = inputs.self + /secrets/singbox-uuid.age;
      singbox-clash-pass.file = inputs.self + /secrets/singbox-clash-pass.age;

      jellyfin-admin-password.file = inputs.self + /secrets/jellyfin-admin-password.age;

      lidarr-password.file = inputs.self + /secrets/lidarr-password.age;
      lidarr-apikey.file = inputs.self + /secrets/lidarr-apikey.age;

      prowlarr-apikey.file = inputs.self + /secrets/prowlarr-apikey.age;
      prowlarr-password.file = inputs.self + /secrets/prowlarr-password.age;

      sabnzbd-apikey.file = inputs.self + /secrets/sabnzbd-apikey.age;
      sabnzbd-nzbkey.file = inputs.self + /secrets/sabnzbd-nzbkey.age;

      jellyseerr-apikey.file = inputs.self + /secrets/jellyseerr-apikey.age;

      rutracker-username.file = inputs.self + /secrets/rutracker-username.age;
      rutracker-password.file = inputs.self + /secrets/rutracker-password.age;

      sonarr-password.file = inputs.self + /secrets/sonarr-password.age;
      sonarr-apikey.file = inputs.self + /secrets/sonarr-apikey.age;

      radarr-password.file = inputs.self + /secrets/radarr-password.age;
      radarr-apikey.file = inputs.self + /secrets/radarr-apikey.age;
    };
  };
}
