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
  name = "hyprpanel";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "window-manager"
      "hypr"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      libnotify
      # optionals
      power-profiles-daemon
      gpu-screen-recorder
      hyprpicker
      hyprsunset
      grimblast
    ];

    programs.hyprpanel = {
      enable = true;
      systemd.enable = false;
      settings = {
        "bar.layouts" = {
          "*" = {
            left = [
              "dashboard"
              "workspaces"
              "windowtitle"
            ];
            middle = [
              "media"
            ];
            right = [
              "kbinput"
              "volume"
              "bluetooth"
              "battery"
              "network"
              "ram"
              "cpu"
              "clock"
              "systray"
              "notifications"
            ];
          };
        };
        "bar.launcher.icon" = "";
        "bar.workspaces.show_numbered" = false;
        "bar.workspaces.workspaces" = 5;
        "bar.workspaces.monitorSpecific" = false;
        "bar.workspaces.hideUnoccupied" = true;
        "bar.windowtitle.label" = true;
        "bar.volume.label" = true;
        "bar.network.truncation_size" = 12;
        "bar.bluetooth.label" = true;
        "bar.clock.format" = "%a %b %Y-%m-%d %H:%M:%S";
        "bar.notifications.show_total" = true;
        "theme.osd.enable" = true;
        "theme.osd.orientation" = "vertical";
        "theme.osd.location" = "right";
        "theme.osd.muted_zero" = false;
        "menus.clock.weather.location" = "Asia/Tehran";
        "menus.clock.weather.unit" = "metric";
        "theme.font.size" = "0.9rem";
        scalingPriority = "hyprland";
        "theme.bar.location" = "bottom";
        "theme.bar.buttons.enableBorders" = false;
      };
    };

    # hyprpanel needs to write to config.json at runtime, but home-manager
    # creates a read-only symlink. Replace it with a writable copy.
    home.activation.hyprpanelConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      cfg_file="$HOME/.config/hyprpanel/config.json"
      if [ -L "$cfg_file" ]; then
        real=$(readlink -f "$cfg_file")
        rm "$cfg_file"
        cp "$real" "$cfg_file"
        chmod 644 "$cfg_file"
      fi
    '';

    wayland.windowManager.hyprland.settings.exec = [
      "pkill hyprpanel; sleep 0.5; ${lib.getExe pkgs.hyprpanel}"
    ];
  };
}
