{ lib, config, pkgs, ... }: {
  programs.waybar = {
    enable = true;
    systemd.enable = false;

    style = ''
      ${builtins.readFile "${pkgs.waybar}/etc/xdg/waybar/style.css"}

      window#waybar {
        background: transparent;
        border-bottom: none;
      }
    '';
    settings = [{
      # height = 30;
      # layer = "top";
      position = "bottom";
      # tray = { spacing = 10; };
      modules-center = [ "sway/window" ];
      modules-left = [ "sway/workspaces" "sway/mode" ];
      modules-right = [
        "privacy"
        "sway/language"
        "network"
        "cpu"
        "memory"
        "wireplumber"
        "clock"
        "tray"
      ];
      #   battery = {
      #     format = "{capacity}% {icon}";
      #     format-alt = "{time} {icon}";
      #     format-charging = "{capacity}% ";
      #     format-icons = [ "" "" "" "" "" ];
      #     format-plugged = "{capacity}% ";
      #     states = {
      #       critical = 15;
      #       warning = 30;
      #     };
      #   };

      wireplumber = {
        format = "{volume}% {icon}";
        format-muted = "";
        format-icons = [ "" "" "" ];
        on-click = "helvum";
        max-volume = 150;
        scroll-step = 0.2;
      };
      privacy = {
        icon-spacing = 4;
        icon-size = 18;
        transition-duration = 250;
        modules = [
          {
            type = "screenshare";
            tooltip = true;
            tooltip-icon-size = 24;
          }
          {
            type = "audio-out";
            tooltip = true;
            tooltip-icon-size = 24;
          }
          {
            type = "audio-in";
            tooltip = true;
            tooltip-icon-size = 24;
          }
        ];
      };
      clock = {
        # format-alt = "{:%Y-%m-%d}";
        format = "{:%Y-%m-%d | %H:%M}";
        tooltip-format = "{:%Y-%m-%d | %H:%M}";
      };
      cpu = { format = "{usage}% "; };
      memory = { format = "{}% "; };
      network = {
        # interval = 1;
        format-alt = "{ifname}: {ipaddr}/{cidr}";
        format-disconnected = "Disconnected ⚠";
        format-ethernet = "{ifname}: {ipaddr}/{cidr} ";
        # format-ethernet =
        #   "{ifname}: {ipaddr}/{cidr}   up: {bandwidthUpBits} down: {bandwidthDownBits}";
        format-linked = "{ifname} (No IP) ";
        format-wifi = "{essid} ({signalStrength}%) ";
      };
      # pulseaudio = {
      #   format = "{volume}% {icon} {format_source}";
      #   format-bluetooth = "{volume}% {icon} {format_source}";
      #   format-bluetooth-muted = " {icon} {format_source}";
      #   format-icons = {
      #     car = "";
      #     default = [ "" "" "" ];
      #     handsfree = "";
      #     headphones = "";
      #     headset = "";
      #     phone = "";
      #     portable = "";
      #   };
      #   format-muted = " {format_source}";
      #   format-source = "{volume}% ";
      #   format-source-muted = "";
      #   on-click = "pavucontrol";
      # };
      "sway/mode" = { format = ''<span style="italic">{}</span>''; };
      temperature = {
        critical-threshold = 80;
        format = "{temperatureC}°C {icon}";
        format-icons = [ "" "" "" ];
      };
    }];
  };
}
