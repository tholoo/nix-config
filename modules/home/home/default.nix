{
  lib,
  config,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = config.mine.user;

  is-linux = pkgs.stdenv.isLinux;
  is-darwin = pkgs.stdenv.isDarwin;

  home-directory =
    if cfg.name == null then
      null
    else if is-darwin then
      "/Users/${cfg.name}"
    else
      "/home/${cfg.name}";
in
with lib;
with lib.mine;
{
  options.mine.user = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to configure the user account.";
    };

    name = mkOption {
      type = types.nullOr types.str;
      default = "tholo";
      description = "The user account.";
    };

    fullName = mkOption {
      type = types.str;
      default = "tholo";
      description = "The full name of the user.";
    };

    email = mkOption {
      type = types.str;
      default = "ali.mohamadza@gmail.com";
      description = "The email of the user.";
    };

    home = mkOption {
      type = types.nullOr types.str;
      default = home-directory;
      description = "The user's home directory.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "mine.user.name must be set";
        }
        {
          assertion = cfg.home != null;
          message = "mine.user.home must be set";
        }
      ];
      programs.home-manager.enable = true;

      # Nicely reload system units when changing configs
      systemd.user.startServices = "sd-switch";

      home = {
        username = mkDefault cfg.name;
        homeDirectory = mkDefault cfg.home;
      };

      xdg.enable = true;

      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      home.stateVersion = lib.mkDefault (osConfig.system.stateVersion or "23.11");
    }
  ]);
}
