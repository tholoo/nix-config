{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "homepage-dashboard";
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
    services.homepage-dashboard = {
      enable = true;
      listenPort = 8082;
      allowedHosts = "localhost:8082,127.0.0.1:8082,192.168.1.101:8082,elderwood:8082";
      openFirewall = true;

      settings = {
        title = "Elderwood";
        headerStyle = "clean";
      };

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
        {
          search = {
            provider = "google";
            target = "_blank";
          };
        }
      ];

      services = [
        {
          "Media" = [
            {
              "Jellyfin" = {
                icon = "jellyfin";
                href = "http://192.168.1.101:8096";
                description = "Media server";
              };
            }
            {
              "Sonarr" = {
                icon = "sonarr";
                href = "http://192.168.1.101:8989";
                description = "TV shows";
              };
            }
            {
              "Radarr" = {
                icon = "radarr";
                href = "http://192.168.1.101:7878";
                description = "Movies";
              };
            }
            {
              "Lidarr" = {
                icon = "lidarr";
                href = "http://192.168.1.101:8686";
                description = "Music";
              };
            }
            {
              "Prowlarr" = {
                icon = "prowlarr";
                href = "http://192.168.1.101:9696";
                description = "Indexer manager";
              };
            }
            {
              "Jellyseerr" = {
                icon = "jellyseerr";
                href = "http://192.168.1.101:5055";
                description = "Request management";
              };
            }
          ];
        }
        {
          "Productivity" = [
            {
              "Paperless-ngx" = {
                icon = "paperless-ngx";
                href = "http://192.168.1.101:28981";
                description = "Document management";
              };
            }
            {
              "Firefly III" = {
                icon = "firefly-iii";
                href = "http://192.168.1.101:8080";
                description = "Finance manager";
              };
            }
            {
              "Mealie" = {
                icon = "mealie";
                href = "http://192.168.1.101:9000";
                description = "Recipe manager";
              };
            }
            {
              "n8n" = {
                icon = "n8n";
                href = "http://192.168.1.101:5678";
                description = "Workflow automation";
              };
            }
          ];
        }
        {
          "Home & Photos" = [
            {
              "Home Assistant" = {
                icon = "home-assistant";
                href = "http://192.168.1.101:8123";
                description = "Home automation";
              };
            }
            {
              "Immich" = {
                icon = "immich";
                href = "http://192.168.1.101:2283";
                description = "Photo management";
              };
            }
          ];
        }
        {
          "Network" = [
            {
              "Mihomo Dashboard" = {
                icon = "clash";
                href = "http://192.168.1.101:9090";
                description = "Proxy dashboard";
              };
            }
            {
              "Proxy Monitor" = {
                href = "http://192.168.1.101:6969";
                description = "Proxy monitor";
              };
            }
            {
              "Uptime Kuma" = {
                icon = "uptime-kuma";
                href = "http://192.168.1.101:3001";
                description = "Service monitoring";
              };
            }
          ];
        }
      ];
    };
  };
}
