{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "stylix";

  theme-switch = pkgs.writeShellScriptBin "theme-switch" ''
    SPEC_DIR="/run/current-system/specialisation"

    if [ -z "$1" ] || [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
      echo "Available themes:"
      for d in "$SPEC_DIR"/*/; do
        basename "$d"
      done
      [ -n "$1" ] && exit 0
      echo ""
      echo "Usage: theme-switch <theme-name>"
      exit 1
    fi

    THEME="$1"
    SWITCH="$SPEC_DIR/$THEME/bin/switch-to-configuration"

    if [ ! -x "$SWITCH" ]; then
      echo "Theme '$THEME' not found."
      echo "Available themes:"
      for d in "$SPEC_DIR"/*/; do
        basename "$d"
      done
      exit 1
    fi

    echo "Switching to $THEME..."
    sudo "$SWITCH" switch
  '';
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "gui"
      "theme"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = [ theme-switch ];

    stylix.targets = {
      # hyprpanel manages its own theming
      hyprpanel.enable = false;
    };
  };
}
