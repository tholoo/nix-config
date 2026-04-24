{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "nixflix";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "personal"
      "media"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    age.secrets = {
      jellyfin-admin-password.file = inputs.self + /secrets/jellyfin/jellyfin-admin-password.age;
      jellyfin-apikey.file = inputs.self + /secrets/jellyfin/jellyfin-apikey.age;
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
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    systemd.services.jellyfin.environment = {
      HTTP_PROXY = "http://127.0.0.1:10808";
      HTTPS_PROXY = "http://127.0.0.1:10808";
      NO_PROXY = "localhost,127.0.0.1";
    };

    environment.systemPackages = [
      pkgs.jellyfin-mpv-shim
    ];

    nixflix = {
      enable = true;
      mediaDir = "/data/media";
      stateDir = "/data/.state";

      nginx.enable = true;
      postgres.enable = true;

      sonarr = {
        enable = true;
        openFirewall = true;
        config = {
          apiKey = {
            _secret = config.age.secrets.sonarr-apikey.path;
          };
          hostConfig = {
            username = "admin";
            password = {
              _secret = config.age.secrets.sonarr-password.path;
            };
          };
        };
      };

      radarr = {
        enable = true;
        openFirewall = true;
        config = {
          apiKey = {
            _secret = config.age.secrets.radarr-apikey.path;
          };
          hostConfig = {
            username = "admin";
            password = {
              _secret = config.age.secrets.radarr-password.path;
            };
          };
        };
      };

      prowlarr = {
        enable = true;
        openFirewall = true;
        config = {
          apiKey = {
            _secret = config.age.secrets.prowlarr-apikey.path;
          };
          hostConfig = {
            username = "admin";
            password = {
              _secret = config.age.secrets.prowlarr-password.path;
            };
          };
          indexers = [
            {
              name = "RuTracker.org";

              username = {
                _secret = config.age.secrets.rutracker-username.path;
              };
              password = {
                _secret = config.age.secrets.rutracker-password.path;
              };

              # Schema fields (must match exactly)
              baseUrl = "https://rutracker.org";
              # "Strip Russian letters"
              russianLetters = true;
            }
            {
              name = "BT.etree";
              baseUrl = "https://bt.etree.org/";
              appProfileId = 1;
              definitionFile = "btetree";
              sort = 0;
            }
          ];
        };
      };

      # sabnzbd = {
      #   enable = true;
      #   settings = {
      #     misc = {
      #       api_key = {
      #         _secret = config.age.secrets.sabnzbd-apikey.path;
      #       };
      #       nzb_key = {
      #         _secret = config.age.secrets.sabnzbd-nzbkey.path;
      #       };
      #     };
      #   };
      # };

      lidarr = {
        enable = true;
        openFirewall = true;
        config = {
          apiKey = {
            _secret = config.age.secrets.lidarr-apikey.path;
          };
          hostConfig = {
            username = "admin";
            password = {
              _secret = config.age.secrets.lidarr-password.path;
            };
          };
        };
      };

      jellyfin = {
        enable = true;
        openFirewall = true;
        network.localNetworkAddresses = [ ];
        apiKey = {
          _secret = config.age.secrets.jellyfin-apikey.path;
        };
        users.admin = {
          policy.isAdministrator = true;
          password = {
            _secret = config.age.secrets.jellyfin-admin-password.path;
          };
        };
      };

      seerr = {
        enable = true;
        openFirewall = true;
        vpn.enable = false;
        apiKey = {
          _secret = config.age.secrets.jellyseerr-apikey.path;
        };
      };
    };
  };
}
