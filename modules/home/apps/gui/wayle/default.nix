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
  name = "wayle";
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
      power-profiles-daemon
      gpu-screen-recorder
      hyprpicker
      hyprsunset
      grimblast
    ];

    services.wayle = {
      enable = true;
      settings = {
        bar = {
          location = "bottom";
          rounding = "sm";
          scale = 0.65;
          padding = 0.12;
          padding-ends = 0.18;
          module-gap = 0.15;
          button-icon-size = 0.7;
          button-icon-padding = 0.42;
          button-label-size = 0.7;
          button-label-padding = 0.42;
          button-gap = 0.3;
          layout = [
            {
              monitor = "*";
              left = [
                "dashboard"
                "hyprland-workspaces"
                "window-title"
              ];
              center = [
                "media"
              ];
              right = [
                "keyboard-input"
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
            }
          ];
        };

        modules = {
          clock = {
            format = "%a %b %Y-%m-%d %H:%M:%S";
            icon-show = false;
            label-show = true;
          };
          hyprland-workspaces = {
            min-workspace-count = 5;
            monitor-specific = false;
          };
          window-title = {
            label-show = true;
          };
          volume = {
            label-show = true;
          };
          bluetooth = {
            label-show = true;
          };
          notifications = {
            label-show = true;
            popup-monitor = "HDMI-A-1";
          };
          weather = {
            location = "Asia/Tehran";
            units = "metric";
          };
        };

        osd = {
          enabled = true;
          position = "right";
        };

        styling = {
          theme-provider = "wayle";
        };
      };
    };
  };
}
