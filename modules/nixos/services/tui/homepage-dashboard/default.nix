{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    optional
    optionals
    filter
    ;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "homepage-dashboard";
  host = "192.168.1.101";
  local = "127.0.0.1";
  envFile = "/run/homepage-dashboard/env";

  # Service enable checks
  jellyfin = config.nixflix.jellyfin.enable;
  sonarr = config.nixflix.sonarr.enable;
  radarr = config.nixflix.radarr.enable;
  lidarr = config.nixflix.lidarr.enable;
  prowlarr = config.nixflix.prowlarr.enable;
  seerr = config.nixflix.seerr.enable;
  paperless = config.mine.paperless.enable;
  firefly = config.mine.firefly-iii.enable;
  mealie = config.mine.mealie.enable;
  n8n = config.mine.n8n.enable;
  homeAssistant = config.mine.home-assistant.enable;
  immich = config.mine.immich.enable;
  mihomo = config.mine.mihomo.enable;
  uptimeKuma = config.mine.uptime-kuma.enable;

  # Helper to filter empty categories
  filterEmpty = list: filter (cat: (builtins.head (builtins.attrValues cat)) != [ ]) list;

  # Env var lines for the env file script
  envLines =
    optional jellyfin "HOMEPAGE_VAR_JELLYFIN_KEY=$(cat ${config.age.secrets.jellyfin-apikey.path})"
    ++ optional sonarr "HOMEPAGE_VAR_SONARR_KEY=$(cat ${config.age.secrets.sonarr-apikey.path})"
    ++ optional radarr "HOMEPAGE_VAR_RADARR_KEY=$(cat ${config.age.secrets.radarr-apikey.path})"
    ++ optional lidarr "HOMEPAGE_VAR_LIDARR_KEY=$(cat ${config.age.secrets.lidarr-apikey.path})"
    ++ optional prowlarr "HOMEPAGE_VAR_PROWLARR_KEY=$(cat ${config.age.secrets.prowlarr-apikey.path})"
    ++ optional seerr "HOMEPAGE_VAR_JELLYSEERR_KEY=$(cat ${config.age.secrets.jellyseerr-apikey.path})";

  hasEnvVars = envLines != [ ];
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
    systemd.services.homepage-dashboard-env = mkIf hasEnvVars {
      description = "Generate Homepage Dashboard environment file";
      wantedBy = [ "homepage-dashboard.service" ];
      before = [ "homepage-dashboard.service" ];
      after = [ "agenix.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "homepage-dashboard";
      };
      script = ''
        cat > ${envFile} <<EOF
        ${builtins.concatStringsSep "\n" envLines}
        EOF
      '';
    };

    systemd.services.homepage-dashboard = mkIf hasEnvVars {
      after = [ "homepage-dashboard-env.service" ];
      requires = [ "homepage-dashboard-env.service" ];
      serviceConfig.EnvironmentFile = envFile;
    };

    services.homepage-dashboard = {
      enable = true;
      listenPort = 8082;
      allowedHosts = "localhost:8082,127.0.0.1:8082,${host}:8082,elderwood:8082";
      openFirewall = true;

      settings = {
        title = "Elderwood";
        headerStyle = "clean";
        theme = "dark";
        color = "slate";
        iconStyle = "theme";
        hideVersion = true;
        layout = {
          Media = {
            style = "row";
            columns = 3;
          };
          Productivity = {
            style = "row";
            columns = 2;
          };
          "Home & Photos" = {
            style = "row";
            columns = 2;
          };
          Network = {
            style = "row";
            columns = 3;
          };
        };
      };

      widgets = [
        {
          datetime = {
            locale = "en";
            format = {
              dateStyle = "long";
              timeStyle = "short";
              hour12 = false;
            };
          };
        }
        {
          resources = {
            cpu = true;
            cputemp = true;
            memory = true;
            disk = "/";
            uptime = true;
          };
        }
        {
          search = {
            provider = "google";
            target = "_blank";
          };
        }
      ];

      bookmarks = [
        {
          "Dev" = [
            {
              "GitHub" = [
                {
                  icon = "github";
                  href = "https://github.com";
                }
              ];
            }
            {
              "NixOS Wiki" = [
                {
                  icon = "nixos";
                  href = "https://wiki.nixos.org";
                }
              ];
            }
            {
              "Home Manager Options" = [
                {
                  icon = "nixos";
                  href = "https://home-manager-options.extranix.com";
                }
              ];
            }
          ];
        }
      ];

      services = filterEmpty [
        {
          "Media" =
            optional jellyfin {
              "Jellyfin" = {
                icon = "jellyfin";
                href = "http://${host}:8096";
                siteMonitor = "http://${host}:8096";
                description = "Media server";
                widget = {
                  type = "jellyfin";
                  url = "http://${local}:8096";
                  key = "{{HOMEPAGE_VAR_JELLYFIN_KEY}}";
                  enableBlocks = true;
                };
              };
            }
            ++ optional sonarr {
              "Sonarr" = {
                icon = "sonarr";
                href = "http://${host}:8989";
                siteMonitor = "http://${host}:8989";
                description = "TV shows";
                widget = {
                  type = "sonarr";
                  url = "http://${local}:8989";
                  key = "{{HOMEPAGE_VAR_SONARR_KEY}}";
                };
              };
            }
            ++ optional radarr {
              "Radarr" = {
                icon = "radarr";
                href = "http://${host}:7878";
                siteMonitor = "http://${host}:7878";
                description = "Movies";
                widget = {
                  type = "radarr";
                  url = "http://${local}:7878";
                  key = "{{HOMEPAGE_VAR_RADARR_KEY}}";
                };
              };
            }
            ++ optional lidarr {
              "Lidarr" = {
                icon = "lidarr";
                href = "http://${host}:8686";
                siteMonitor = "http://${host}:8686";
                description = "Music";
                widget = {
                  type = "lidarr";
                  url = "http://${local}:8686";
                  key = "{{HOMEPAGE_VAR_LIDARR_KEY}}";
                };
              };
            }
            ++ optional prowlarr {
              "Prowlarr" = {
                icon = "prowlarr";
                href = "http://${host}:9696";
                siteMonitor = "http://${host}:9696";
                description = "Indexer manager";
                widget = {
                  type = "prowlarr";
                  url = "http://${local}:9696";
                  key = "{{HOMEPAGE_VAR_PROWLARR_KEY}}";
                };
              };
            }
            ++ optional seerr {
              "Jellyseerr" = {
                icon = "jellyseerr";
                href = "http://${host}:5055";
                siteMonitor = "http://${host}:5055";
                description = "Request management";
                widget = {
                  type = "jellyseerr";
                  url = "http://${local}:5055";
                  key = "{{HOMEPAGE_VAR_JELLYSEERR_KEY}}";
                };
              };
            };
        }
        {
          "Productivity" =
            optional paperless {
              "Paperless-ngx" = {
                icon = "paperless-ngx";
                href = "http://${host}:28981";
                siteMonitor = "http://${host}:28981";
                description = "Document management";
              };
            }
            ++ optional firefly {
              "Firefly III" = {
                icon = "firefly-iii";
                href = "http://${host}:8080";
                siteMonitor = "http://${host}:8080";
                description = "Finance manager";
              };
            }
            ++ optional mealie {
              "Mealie" = {
                icon = "mealie";
                href = "http://${host}:9000";
                siteMonitor = "http://${host}:9000";
                description = "Recipe manager";
              };
            }
            ++ optional n8n {
              "n8n" = {
                icon = "n8n";
                href = "http://${host}:5678";
                siteMonitor = "http://${host}:5678";
                description = "Workflow automation";
              };
            };
        }
        {
          "Home & Photos" =
            optional homeAssistant {
              "Home Assistant" = {
                icon = "home-assistant";
                href = "http://${host}:8123";
                siteMonitor = "http://${host}:8123";
                description = "Home automation";
              };
            }
            ++ optional immich {
              "Immich" = {
                icon = "immich";
                href = "http://${host}:2283";
                siteMonitor = "http://${host}:2283";
                description = "Photo management";
              };
            };
        }
        {
          "Network" =
            optional mihomo {
              "Mihomo Dashboard" = {
                icon = "clash";
                href = "http://${host}:9090";
                description = "Proxy dashboard";
              };
            }
            ++ optional mihomo {
              "Proxy Monitor" = {
                href = "http://${host}:6969";
                siteMonitor = "http://${host}:6969";
                description = "Proxy monitor";
              };
            }
            ++ optional uptimeKuma {
              "Uptime Kuma" = {
                icon = "uptime-kuma";
                href = "http://${host}:3001";
                siteMonitor = "http://${host}:3001";
                description = "Service monitoring";
              };
            };
        }
      ];
    };
  };
}
