{
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
      "gui"
      "media"
    ];
  };

  config = mkIf cfg.enable {
    nixflix = {
      enable = true;
      mediaDir = "/data/media";
      stateDir = "/data/.state";

      nginx.enable = true;
      postgres.enable = true;

      sonarr = {
        enable = true;
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
              name = "Nyaa.si";
              apiKey = {
                _secret = config.age.secrets.dummy-apikey.path;
              };
            }
            {
              name = "BT.etree";
              apiKey = {
                _secret = config.age.secrets.dummy-apikey.path;
              };
            }
            {
              name = "The Pirate Bay";
              apiKey = {
                _secret = config.age.secrets.dummy-apikey.path;
              };
            }
            {
              name = "BitSearch";
              apiKey = {
                _secret = config.age.secrets.dummy-apikey.path;
              };
            }
            {
              name = "ExtraTorrent.st";
              apiKey = {
                _secret = config.age.secrets.dummy-apikey.path;
              };
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
        users.admin = {
          policy.isAdministrator = true;
          password = {
            _secret = config.age.secrets.jellyfin-admin-password.path;
          };
        };
      };

      jellyseerr = {
        enable = true;
        vpn.enable = false;
        apiKey = {
          _secret = config.age.secrets.jellyseerr-apikey.path;
        };
      };
    };
  };
}
