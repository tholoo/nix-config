let
  mkAll = attrs: attrs // { all = builtins.attrValues (removeAttrs attrs [ "all" ]); };

  users = mkAll {
    tholo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF";
    tholo_glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM81VuTolmcvR3GSa5ZjcC2MQAD2l6EGgM44ZLo9Wp3U";
    tholo_elderwood = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICZD/kmJU6dEYVxb2hI2OnpZ4AkBccyzXNZq895uqesr";
  };

  systems = mkAll {
    granite = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA0okJ7bbZOM7BWgZ76dvO3VJp+ouPfosrBlXHsyumt6";
    glacier = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN3a+4xjTkW2KPGTbGtZMhzS++0Tq9/7KFlMS96t8koi";
    ahm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJrMl4Ne28Pl6LxsI/IsbSA4QK/wBzi/GfX4/jB/KbJt";
    elderwood = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDNCUmOYolaXlqx+igGBzt2MgrwLlSooXI6RMFfMyiq";
    flint = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGku/f5jWB3r+JCFHR2RrKyVvefYYnD+CgCt8TpcAxKb";
  };
  # hosts that run specific services
  mediaHosts = [ systems.elderwood ];
  proxyHosts = [
    systems.glacier
    systems.elderwood
  ];
  dokployHosts = [ systems.granite ];
  mailHosts = [ ];
in
{
  "firefly/firefly-app-key.age".publicKeys = users.all ++ [ systems.elderwood ];

  "mihomo/mihomo-sub-url-main.age".publicKeys = users.all ++ proxyHosts;

  "mail/mail-user1-password.age".publicKeys = users.all ++ mailHosts;

  "dokploy/dokploy-db-password.age".publicKeys = users.all ++ dokployHosts;

  # IPs — all users and systems need these for SSH
  "ips/ip-granite.age".publicKeys = users.all ++ systems.all;
  "ips/ip-flint.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-hetzner-germany.age".publicKeys = users.all ++ systems.all;
  "ips/ip-ahmad-hetzner-germany.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-iranserver-tehran.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-asiatech-tehran.age".publicKeys = users.all ++ systems.all;
  "ips/ip-parsa-asiatech-tehran2.age".publicKeys = users.all ++ systems.all;
  "ips/ip-mohammad-do.age".publicKeys = users.all ++ systems.all;

  "singbox/singbox-domain.age".publicKeys = users.all ++ proxyHosts;
  "singbox/singbox-header-domain.age".publicKeys = users.all ++ proxyHosts;
  "singbox/singbox-uuid.age".publicKeys = users.all ++ proxyHosts;
  "singbox/singbox-clash-pass.age".publicKeys = users.all ++ proxyHosts;

  "jellyfin/jellyfin-admin-password.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/jellyfin-apikey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/lidarr-apikey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/lidarr-password.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/prowlarr-apikey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/prowlarr-password.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/sabnzbd-apikey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/sabnzbd-nzbkey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/jellyseerr-apikey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/rutracker-username.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/rutracker-password.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/sonarr-apikey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/sonarr-password.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/radarr-apikey.age".publicKeys = users.all ++ mediaHosts;
  "jellyfin/radarr-password.age".publicKeys = users.all ++ mediaHosts;
}
