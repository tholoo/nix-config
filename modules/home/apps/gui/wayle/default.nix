{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe getExe' mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "wayle";
  vigiland = inputs.vigiland.packages.${pkgs.stdenv.hostPlatform.system}.vigiland;
  vigilandControl = pkgs.writeShellApplication {
    name = "vigiland-control";
    runtimeInputs = with pkgs; [
      coreutils
      procps
      util-linux
    ];
    text = ''
      user_id="$(id -u)"

      is_active() {
        pgrep -u "$user_id" -x vigiland > /dev/null
      }

      show_status() {
        if is_active; then
          printf '%s\n' '{"alt":"active","state":"On","tooltip":"Vigiland is active; click to allow idle"}'
        else
          printf '%s\n' '{"alt":"inactive","state":"Off","tooltip":"Vigiland is inactive; click to inhibit idle"}'
        fi
      }

      case "''${1:-status}" in
        status)
          show_status
          ;;
        toggle)
          runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
          exec 9>"$runtime_dir/vigiland-control-$user_id.lock"
          flock -x 9

          if is_active; then
            pkill -u "$user_id" -x vigiland || true
            for _ in {1..20}; do
              is_active || break
              sleep 0.05
            done
          else
            nohup ${getExe' vigiland "vigiland"} > /dev/null 2>&1 9>&- &
            for _ in {1..20}; do
              is_active && break
              sleep 0.05
            done
          fi
          ;;
        *)
          printf 'usage: vigiland-control {status|toggle}\n' >&2
          exit 2
          ;;
      esac
    '';
  };
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
                "custom-vigiland"
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
          custom = [
            {
              id = "vigiland";
              command = "${getExe vigilandControl} status";
              interval-ms = 2000;
              format = "Vigiland {{ state }}";
              tooltip-format = "{{ tooltip }}";
              icon-map = {
                active = "tb-coffee-symbolic";
                inactive = "tb-coffee-off-symbolic";
              };
              left-click = "${getExe vigilandControl} toggle";
              on-action = "${getExe vigilandControl} status";
            }
          ];
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
