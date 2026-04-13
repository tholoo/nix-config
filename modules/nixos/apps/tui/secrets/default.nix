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
      singbox-domain.file = inputs.self + /secrets/singbox/singbox-domain.age;
      singbox-header-domain.file = inputs.self + /secrets/singbox/singbox-header-domain.age;
      singbox-uuid.file = inputs.self + /secrets/singbox/singbox-uuid.age;
      singbox-clash-pass.file = inputs.self + /secrets/singbox/singbox-clash-pass.age;

      jellyfin-admin-password.file = inputs.self + /secrets/jellyfin/jellyfin-admin-password.age;

      lidarr-password.file = inputs.self + /secrets/jellyfin/lidarr-password.age;
      lidarr-apikey.file = inputs.self + /secrets/jellyfin/lidarr-apikey.age;

      prowlarr-apikey.file = inputs.self + /secrets/jellyfin/prowlarr-apikey.age;
      prowlarr-password.file = inputs.self + /secrets/jellyfin/prowlarr-password.age;

      sabnzbd-apikey.file = inputs.self + /secrets/jellyfin/sabnzbd-apikey.age;
      sabnzbd-nzbkey.file = inputs.self + /secrets/jellyfin/sabnzbd-nzbkey.age;

      jellyseerr-apikey.file = inputs.self + /secrets/jellyfin/jellyseerr-apikey.age;

      rutracker-username.file = inputs.self + /secrets/jellyfin/rutracker-username.age;
      rutracker-password.file = inputs.self + /secrets/jellyfin/rutracker-password.age;

      sonarr-password.file = inputs.self + /secrets/jellyfin/sonarr-password.age;
      sonarr-apikey.file = inputs.self + /secrets/jellyfin/sonarr-apikey.age;

      radarr-password.file = inputs.self + /secrets/jellyfin/radarr-password.age;
      radarr-apikey.file = inputs.self + /secrets/jellyfin/radarr-apikey.age;

      dokploy-db-password.file = inputs.self + /secrets/dokploy/dokploy-db-password.age;
    };
  };
}
