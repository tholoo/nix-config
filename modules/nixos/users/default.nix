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
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM81VuTolmcvR3GSa5ZjcC2MQAD2l6EGgM44ZLo9Wp3U tholo@glacier"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYrWi1/IR56l4LXk5wtJuUSHN7U3baYLvqmlTFfmNA3 root@nixos"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDP5NAC+t7dRdeCUVaMPRUvfu4hrFLqEqpmh8NlXORwF tholo@nixos"
      ];
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
