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
          modules-center =
            if config.wayland.windowManager.sway.enable then [ "sway/window" ] else [ "hyprland/window" ];
          modules-left =
            if config.wayland.windowManager.sway.enable then
              [
                "sway/workspaces"
                "sway/mode"
              ]
            else
              [
                "hyprland/workspaces"
                "hyprland/submap"
              ];
          modules-right =
            [ "privacy" ]
            ++ (
              if config.wayland.windowManager.sway.enable then [ "sway/language" ] else [ "hyprland/language" ]
            )
            ++ [
              "network"
              "cpu"
              "memory"
              "wireplumber"
              "clock"
              "tray"
            ];
          battery = {
            states = {
              warning = 30;
              critical = 15;
            };
            max-length = 20;
            format = "{icon} {capacity}%";
            format-warning = "{icon} {capacity}%";
            format-critical = "{icon} {capacity}%";
            format-charging = "<span font-family='Font Awesome 6 Free'></span> {capacity}%";
            format-plugged = " Plugged";

            format-alt = "{icon} {time}";
            format-full = "";
            format-icons = [
              "󱊡"
              "󱊢"
              "󱊣"
            ];
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
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
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
            interval = 30;
            format = " {}%";
            format-alt = " {used:0.1f}GB";
            max-length = 10;
          };
          network = {
            # "format-wifi" = "直",
            format-wifi = "{icon} {essid}";
            format-ethernet = "󰛳 Online";
            format-disconnected = "󰅛 Offline";
            tooltip-format = "{essid}";
            on-click = "kitty -e nmtui";
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
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
