{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.mine.users;
in
with lib;
with lib.mine;
{
  options.mine.users = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to configure users.";
    };

    name = mkOption {
      type = with types; (nullOr str);
      default = "tholo";
      description = "the host name";
    };

    authorizedKeys = mkOption {
      type = with types; (listOf str);
      default = [ ];
      description = "the authorized keys";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "mine.host.name must be set";
        }
      ];
      users.users = {
        root = {
          openssh.authorizedKeys.keys = cfg.authorizedKeys;
        };

        "${cfg.name}" = {
          initialPassword = "1234";
          isNormalUser = true;
          shell = pkgs.fish;
          openssh.authorizedKeys.keys = cfg.authorizedKeys;
          extraGroups = [
            "wheel"
            "networkmanager"
            "audio"
            "docker"
            "video"
            "input"
            "libvirtd"
          ];
        };
      };
    }
  ]);
}
