{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;

  name = "cosmic-term";
  cfg = config.mine.${name};
  selected = config.mine.terminal.emulator == name;
  colors = config.lib.stylix.colors.withHashtag;
  configDir = "cosmic/com.system76.CosmicTerm/v1";

  launcher = pkgs.writeShellApplication {
    name = "cosmic-term-launch";
    runtimeInputs = [ pkgs.cosmic-term ];
    text = ''
      if [[ ''${1-} == "-e" ]]; then
        shift
      fi

      # A terminal opened from Zellij or SSH should start a fresh local shell.
      unset SSH_CLIENT SSH_CONNECTION ZELLIJ ZELLIJ_PANE_ID ZELLIJ_SESSION_NAME

      if (( $# == 0 )); then
        exec cosmic-term
      fi

      exec cosmic-term -- "$@"
    '';
  };
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "terminal"
    ];
  };

  config = mkIf (cfg.enable && selected) {
    home.packages = [
      pkgs.cosmic-term
      launcher
    ];

    xdg.configFile = {
      "${configDir}/app_theme" = {
        force = true;
        text = "Dark";
      };
      "${configDir}/color_schemes_dark" = {
        force = true;
        text = ''
          {
            0: (
              name: "Stylix",
              foreground: "${colors.base05}",
              background: "${colors.base00}",
              cursor: "${colors.base05}",
              bright_foreground: "${colors.base07}",
              dim_foreground: "${colors.base03}",
              normal: (
                black: "${colors.base00}",
                red: "${colors.base08}",
                green: "${colors.base0B}",
                yellow: "${colors.base0A}",
                blue: "${colors.base0D}",
                magenta: "${colors.base0E}",
                cyan: "${colors.base0C}",
                white: "${colors.base05}",
              ),
              bright: (
                black: "${colors.base03}",
                red: "${colors.base08}",
                green: "${colors.base0B}",
                yellow: "${colors.base0A}",
                blue: "${colors.base0D}",
                magenta: "${colors.base0E}",
                cyan: "${colors.base0C}",
                white: "${colors.base07}",
              ),
              dim: (
                black: "${colors.base00}",
                red: "${colors.base08}",
                green: "${colors.base0B}",
                yellow: "${colors.base0A}",
                blue: "${colors.base0D}",
                magenta: "${colors.base0E}",
                cyan: "${colors.base0C}",
                white: "${colors.base03}",
              ),
            ),
          }
        '';
      };
      "${configDir}/font_name" = {
        force = true;
        text = ''"${config.stylix.fonts.monospace.name}"'';
      };
      "${configDir}/font_size" = {
        force = true;
        text = "16";
      };
      "${configDir}/opacity" = {
        force = true;
        text = "100";
      };
      "${configDir}/show_headerbar" = {
        force = true;
        text = "false";
      };
      "${configDir}/show_pane_borders" = {
        force = true;
        text = "false";
      };
      "${configDir}/syntax_theme_dark" = {
        force = true;
        text = ''"Stylix"'';
      };
      "${configDir}/tab_new_inherit_working_directory" = {
        force = true;
        text = "true";
      };
      "${configDir}/use_bright_bold" = {
        force = true;
        text = "true";
      };
    };
  };
}
