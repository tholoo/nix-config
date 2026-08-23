{
  lib,
  config,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = config.mine.user;
  terminalCfg = config.mine.terminal;

  terminals = {
    cosmic-term = {
      command = "cosmic-term-launch";
      chooserCommand = "hyprctl dispatch exec '[workspace current; float; size 80% 60%; center]' cosmic-term-launch";
      desktopId = "com.system76.CosmicTerm.desktop";
      classRegex = "com\\.system76\\.CosmicTerm";
    };
    ghostty = {
      command = "ghostty";
      chooserCommand = "ghostty --gtk-single-instance=false --class=dev.terminal.chooser -e";
      desktopId = "com.mitchellh.ghostty.desktop";
      classRegex = "com\\.mitchellh\\.ghostty|ghostty";
    };
    wezterm = {
      command = "wezterm";
      chooserCommand = "wezterm start --always-new-process --class dev.terminal.chooser --";
      desktopId = "org.wezfurlong.wezterm.desktop";
      classRegex = "org\\.wezfurlong\\.wezterm";
    };
  };

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

  options.mine.terminal = {
    emulator = mkOption {
      type = types.enum (builtins.attrNames terminals);
      default = "wezterm";
      description = "Terminal emulator used by launchers and desktop integrations.";
    };

    command = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
    };

    chooserCommand = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
    };

    desktopId = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
    };

    classRegex = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
    };

    chooserClassRegex = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
    };
  };

  config = mkMerge [
    {
      mine.terminal.command = terminals.${terminalCfg.emulator}.command;
      mine.terminal.chooserCommand = terminals.${terminalCfg.emulator}.chooserCommand;
      mine.terminal.desktopId = terminals.${terminalCfg.emulator}.desktopId;
      mine.terminal.classRegex = terminals.${terminalCfg.emulator}.classRegex;
      mine.terminal.chooserClassRegex = "dev\\.terminal\\.chooser";
    }
    (mkIf cfg.enable {
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
    })
  ];
}
