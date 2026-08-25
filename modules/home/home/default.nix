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

  cosmicTermChooser = pkgs.writeShellApplication {
    name = "cosmic-term-chooser";
    excludeShellChecks = [
      "SC2016" # The single-quoted string is an intentional bash -c script.
      "SC2329" # cleanup is invoked indirectly by the EXIT trap.
    ];
    runtimeInputs = [
      pkgs.coreutils
      pkgs.cosmic-term
    ];
    text = ''
      runtime_root="''${XDG_RUNTIME_DIR:-/tmp}"
      state_dir="$(mktemp -d "$runtime_root/cosmic-term-chooser.XXXXXX")"
      started_file="$state_dir/started"
      finished_file="$state_dir/finished"

      cleanup() {
        rm -f -- "$started_file" "$finished_file"
        rmdir -- "$state_dir" 2>/dev/null || true
      }
      trap cleanup EXIT

      # A chooser launched from Zellij or SSH must run in the local desktop
      # session, just like the regular Cosmic Terminal launcher.
      unset SSH_CLIENT SSH_CONNECTION ZELLIJ ZELLIJ_PANE_ID ZELLIJ_SESSION_NAME

      ${lib.getExe pkgs.cosmic-term} -- ${lib.getExe pkgs.bash} -c '
        started_file=$1
        finished_file=$2
        shift 2

        record_exit() {
          status=$?
          printf "%s\n" "$status" > "$finished_file"
        }
        trap record_exit EXIT

        # Mark the window so compositors can style chooser terminals.
        printf "\033]0;dev.terminal.chooser\007"
        : > "$started_file"
        "$@"
      ' cosmic-term-chooser-child "$started_file" "$finished_file" "$@" &
      terminal_pid=$!

      started=false
      for _ in $(seq 1 100); do
        if [[ -e "$started_file" ]]; then
          started=true
          break
        fi
        sleep 0.05
      done

      if [[ "$started" != true ]]; then
        if kill -0 "$terminal_pid" 2>/dev/null; then
          kill "$terminal_pid" 2>/dev/null || true
        fi
        echo "Cosmic Terminal did not start the file chooser" >&2
        exit 1
      fi

      while [[ ! -s "$finished_file" ]]; do
        sleep 0.05
      done

      read -r chooser_status < "$finished_file"
      if [[ ! "$chooser_status" =~ ^[0-9]+$ ]]; then
        echo "Cosmic Terminal returned an invalid chooser status" >&2
        exit 1
      fi
      exit "$chooser_status"
    '';
  };

  terminals = {
    cosmic-term = {
      command = "cosmic-term-launch";
      chooserCommand = lib.getExe cosmicTermChooser;
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
