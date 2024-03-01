{ config, pkgs, lib, ... }: {
  # Use sway desktop environment with Wayland display server
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # Sway-specific Configuration
    config = rec {
      modifier = "Mod4";
      terminal = "wezterm";
      defaultWorkspace = "1";
      menu = "${pkgs.wofi}/bin/wofi --show run";
      startup = [
        # Launch Firefox on start
        { command = "firefox"; }
        {
          command = "wezterm";
        }
        # { command = "systemctl --user restart waybar"; always = true; }
      ];
      assigns = {
        "1" = [{ app_id = "^org.wezfurlong.wezterm$"; }];
        "2" = [{ app_id = "^firefox$"; }];
      };
      # bars = [{
      #   #   fonts.size = 15.0;
      #   # command = "${pkgs.waybar}/bin/waybar";
      #   position = "bottom";
      #   # statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs";
      # }];
      input = {
        "*" = {
          xkb_layout = "us,ir";
          xkb_options = "caps:escape,grp:alt_shift_toggle";
        };
      };
      window = {
        hideEdgeBorders = "smart";
        titlebar = false;
      };
      keybindings = lib.mkOptionDefault {
        "Print" = "exec ${pkgs.shotman}/bin/shotman -c output";
        "Print+Shift" = "exec ${pkgs.shotman}/bin/shotman -c region";
        "Print+Shift+Control" = "exec ${pkgs.shotman}/bin/shotman -c window";
      };
      output = {
        "*" = {
          bg =
            "${../../../resources/wallpapers/wallhaven-fields-858z32.png} fill";
        };
      };
      # Display device configuration
      # output = {
      #   eDP-1 = {
      #     # Set HIDP scale (pixel integer scaling)
      #     scale = "1";
      #   };
      # };
    };
  };
}
