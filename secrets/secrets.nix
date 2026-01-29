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
  "ip-granite.age".publicKeys = users.all ++ systems.all;
  "ip-ahm.age".publicKeys = users.all ++ systems.all;
  "singbox-domain.age".publicKeys = users.all ++ systems.all;
  "singbox-header-domain.age".publicKeys = users.all ++ systems.all;
  "singbox-uuid.age".publicKeys = users.all ++ systems.all;
  "singbox-clash-pass.age".publicKeys = users.all ++ systems.all;

  "jellyfin-admin-password.age".publicKeys = users.all ++ systems.all;
  "lidarr-apikey.age".publicKeys = users.all ++ systems.all;
  "lidarr-password.age".publicKeys = users.all ++ systems.all;
  "prowlarr-apikey.age".publicKeys = users.all ++ systems.all;
  "prowlarr-password.age".publicKeys = users.all ++ systems.all;
  "sabnzbd-apikey.age".publicKeys = users.all ++ systems.all;
  "sabnzbd-nzbkey.age".publicKeys = users.all ++ systems.all;
  "jellyseerr-apikey.age".publicKeys = users.all ++ systems.all;
  "rutracker-username.age".publicKeys = users.all ++ systems.all;
  "rutracker-password.age".publicKeys = users.all ++ systems.all;
  "sonarr-apikey.age".publicKeys = users.all ++ systems.all;
  "sonarr-password.age".publicKeys = users.all ++ systems.all;
  "radarr-apikey.age".publicKeys = users.all ++ systems.all;
  "radarr-password.age".publicKeys = users.all ++ systems.all;
}
