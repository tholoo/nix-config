{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "waybar";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "wayland"
      "gui-bar"
    ];
  };

  config = mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      systemd.enable = false;

      # style = ''
      #   ${builtins.readFile "${pkgs.waybar}/etc/xdg/waybar/style.css"}
      #
      #   window#waybar {
      #     background: transparent;
      #     border-bottom: none;
      #   }
      # '';
      style = builtins.readFile ./style.css;
      settings = [
        {
          # height = 30;
          # layer = "top";
          position = "bottom";
          # tray = { spacing = 10; };
          modules-center = [ "sway/window" ];
          modules-left = [
            "sway/workspaces"
            "sway/mode"
          ];
          modules-right = [
            "privacy"
            "sway/language"
            # "network"
            "cpu"
            "memory"
            "wireplumber"
            "clock"
            "tray"
          ];
          battery = {
            format = "{capacity}% {icon}";
            format-alt = "{time} {icon}";
            format-charging = "{capacity}% ";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
            format-plugged = "{capacity}% ";
            states = {
              critical = 15;
              warning = 30;
            };
          };

          wireplumber = {
            format = "{volume}% {icon}";
            format-muted = "";
            format-icons = [
              ""
              ""
              ""
            ];
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
          cpu = {
            format = "{usage}% ({load}) {icon} ";
            # interval = 1
            format-icons = [
              "<span color='#69ff94'>▁</span>"
              "<span color='#2aa9ff'>▂</span>"
              "<span color='#f8f8f2'>▃</span>"
              "<span color='#f8f8f2'>▄</span>"
              "<span color='#ffffa5'>▅</span>"
              "<span color='#ffffa5'>▆</span>"
              "<span color='#ff9977'>▇</span>"
              "<span color='#dd532e'>█</span>"
            ];
          };
          memory = {
            format = "{}% ";
          };
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
          "sway/mode" = {
            format = ''<span style="italic">{}</span>'';
          };
          temperature = {
            critical-threshold = 80;
            format = "{temperatureC}°C {icon}";
            format-icons = [
              ""
              ""
              ""
            ];
          };
        }
      ];
    };
  };
}
