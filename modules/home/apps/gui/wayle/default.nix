{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe mkIf optional;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "wayle";
  vigiland = config.mine.vigiland;
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
    # Wayle's audio/OSD watcher must start after the user PipeWire graph is
    # available. Otherwise it can bind to the transient auto_null sink during
    # login and never follow the real default output afterward.
    systemd.user.services.wayle.Unit = {
      Wants = [
        "pipewire.service"
        "pipewire-pulse.service"
        "wireplumber.service"
      ];
      After = [
        "pipewire.service"
        "pipewire-pulse.service"
        "wireplumber.service"
      ];
    };
    # Wayle reads raw evdev events, so it shows a Caps Lock OSD even though
    # Caps is remapped to Escape. Hide input devices to disable lock-key OSDs
    # without rebuilding Wayle or disabling its volume and brightness OSDs.
    systemd.user.services.wayle.Service.InaccessiblePaths = [ "/dev/input" ];

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
          scale = 0.82;
          padding = 0.28;
          padding-ends = 0.42;
          module-gap = 0.36;
          button-icon-size = 0.85;
          button-icon-padding = 0.78;
          button-label-size = 0.85;
          button-label-padding = 0.78;
          button-gap = 0.62;
          layout = [
            {
              monitor = "*";
              left = [
                "dashboard"
                "hyprland-workspaces"
                "window-title"
              ]
              ++ optional vigiland.enable "custom-vigiland";
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
          custom = optional vigiland.enable {
            id = "vigiland";
            command = "${getExe vigiland.controlPackage} status";
            interval-ms = 2000;
            format = "Vigiland {{ state }}";
            tooltip-format = "{{ tooltip }}";
            icon-map = {
              active = "tb-coffee-symbolic";
              inactive = "tb-coffee-off-symbolic";
            };
            left-click = "${getExe vigiland.controlPackage} toggle";
            on-action = "${getExe vigiland.controlPackage} status";
          };
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
          monitor = "HDMI-A-1";
          position = "right";
        };

        styling = {
          theme-provider = "wayle";
        };
      };
    };
  };
}
