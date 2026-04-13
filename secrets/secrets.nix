let
  mkAll = attrs: attrs // { all = builtins.attrValues (builtins.removeAttrs attrs [ "all" ]); };

  users = mkAll {
    tholo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF";
    tholo_glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM81VuTolmcvR3GSa5ZjcC2MQAD2l6EGgM44ZLo9Wp3U";
  };

  systems = mkAll {
    granite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0okJ7bbZOM7BWgZ76dvO3VJp+ouPfosrBlXHsyumt6";
    glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN3a+4xjTkW2KPGTbGtZMhzS++0Tq9/7KFlMS96t8koi";
    ahm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJrMl4Ne28Pl6LxsI/IsbSA4QK/wBzi/GfX4/jB/KbJt";
  };
in
{
  "dokploy/dokploy-db-password.age".publicKeys = users.all ++ systems.all;

  "ips/ip-granite.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-hetzner-germany.age".publicKeys = users.all ++ systems.all;
  "ips/ip-ahmad-hetzner-germany.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-iranserver-tehran.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-asiatech-tehran.age".publicKeys = users.all ++ systems.all;
  "ips/ip-ahmad-parspack-tehran.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-asiatech-tehran2.age".publicKeys = users.all ++ systems.all;
  "ips/ip-mohammad-do.age".publicKeys = users.all ++ systems.all;

  "singbox/singbox-domain.age".publicKeys = users.all ++ systems.all;
  "singbox/singbox-header-domain.age".publicKeys = users.all ++ systems.all;
  "singbox/singbox-uuid.age".publicKeys = users.all ++ systems.all;
  "singbox/singbox-clash-pass.age".publicKeys = users.all ++ systems.all;

  "jellyfin/jellyfin-admin-password.age".publicKeys = users.all ++ systems.all;
  "jellyfin/lidarr-apikey.age".publicKeys = users.all ++ systems.all;
  "jellyfin/lidarr-password.age".publicKeys = users.all ++ systems.all;
  "jellyfin/prowlarr-apikey.age".publicKeys = users.all ++ systems.all;
  "jellyfin/prowlarr-password.age".publicKeys = users.all ++ systems.all;
  "jellyfin/sabnzbd-apikey.age".publicKeys = users.all ++ systems.all;
  "jellyfin/sabnzbd-nzbkey.age".publicKeys = users.all ++ systems.all;
  "jellyfin/jellyseerr-apikey.age".publicKeys = users.all ++ systems.all;
  "jellyfin/rutracker-username.age".publicKeys = users.all ++ systems.all;
  "jellyfin/rutracker-password.age".publicKeys = users.all ++ systems.all;
  "jellyfin/sonarr-apikey.age".publicKeys = users.all ++ systems.all;
  "jellyfin/sonarr-password.age".publicKeys = users.all ++ systems.all;
  "jellyfin/radarr-apikey.age".publicKeys = users.all ++ systems.all;
  "jellyfin/radarr-password.age".publicKeys = users.all ++ systems.all;
}
