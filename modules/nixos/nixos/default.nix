{
  pkgs,
  lib,
  config,
  osConfig ? { },
  ...
}:
let
  cfg = config.mine.host;
in
with lib;
with lib.mine;
{
  options.mine.host = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to configure the os.";
    };

    name = mkOption {
      type = types.nullOr types.str;
      default = "nixos";
      description = "the host name";
    };

    location = mkOption {
      type = types.nullOr types.str;
      default = "Asia/Tehran";
      description = "the host location";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "mine.host.name must be set";
        }
        {
          assertion = cfg.location != null;
          message = "mine.host.location must be set";
        }
      ];

      time.timeZone = "Asia/Tehran";

      environment.systemPackages = with pkgs; [
        git
        vim
        neovim
        wget
        curl

        home-manager

        qemu
      ];

      environment.variables = {
        EDITOR = "nvim";
        SUDO_EDITOR = "nvim";
        # Native wayland support
        NIXOS_OZONE_WL = "1";
        GDK_BACKEND = "wayland";
      };

      services.openssh = {
        enable = true;
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
        settings = {
          # Forbid root login through SSH.
          # PermitRootLogin = "no";
          # Use keys only. Remove if you want to SSH using password (not recommended)
          PasswordAuthentication = false;
        };
      };
      # Copy the NixOS configuration file and link it from the resulting system
      # (/run/current-system/configuration.nix). This is useful in case you
      # accidentally delete configuration.nix.
      # system.copySystemConfiguration = true;

      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      system.stateVersion = lib.mkDefault "23.11";
    }
  ]);
}
