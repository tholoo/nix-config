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
      type = types.nullOr types.str;
      default = "tholo";
      description = "the host name";
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
        "${cfg.name}" = {
          initialPassword = "1234";
          isNormalUser = true;
          shell = pkgs.fish;
          openssh.authorizedKeys.keys = [
            # TODO: 
          ];
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
