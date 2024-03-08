{ config, pkgs, lib, options, ... }: {
  # Use sway desktop environment with Wayland display server
  home.packages = options.home.packages.default
    ++ (with pkgs; [ swaynotificationcenter ]);
  programs.swaylock = {
    enable = true;
    settings = {
      image = "${../../../resources/wallpapers/wallhaven-car-swamp.png}";
      ignore-empty-password = true;
      show-failed-attempts = true;
      scaling = "fit";
      font-size = 25;
      indicator-radius = 100;
    };
  };
  # for showing notifications for common actions like changing volume
  services.swayosd.enable = true;
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # Sway-specific Configuration
    config = rec {
      modifier = "Mod4";
      terminal = "wezterm";
      workspaceAutoBackAndForth = true;
      defaultWorkspace = "1";
      menu = "${pkgs.wofi}/bin/wofi --show run";
      gaps = {
        smartGaps = true;
        smartBorders = "on";
      };
      startup = [
        { command = "vivaldi"; }
        { command = "wezterm"; }
        { command = "exec ${pkgs.swaynotificationcenter}/bin/swaync"; }
        {
          command = "telegram-desktop";
        }
        # { command = "systemctl --user restart waybar"; always = true; }
      ];
      assigns = {
        "1" = [{ app_id = "^org.wezfurlong.wezterm$"; }];
        "2" = [ { app_id = "^firefox$"; } { app_id = "vivaldi-stable"; } ];
        "3" = [{ app_id = "org.telegram.desktop"; }];
      };
      bars = [{
        #   fonts.size = 15.0;
        command = "waybar";
        position = "bottom";
        # statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs";
      }];
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
        # "Print" = "exec ${pkgs.shotman}/bin/shotman -c output";
        # "Print+Shift" = "exec ${pkgs.shotman}/bin/shotman -c region";
        # "Print+Shift+Control" = "exec ${pkgs.shotman}/bin/shotman -c window";
        # "Print" = ''exec --no-startup-id "${pkgs.flameshot}/bin/flameshot"'';
        "Print" = ''
          exec ${pkgs.wayshot}/bin/wayshot -s "$(${pkgs.slurp}/bin/slurp)" --stdout | ${pkgs.satty}/bin/satty --filename -'';

        "Insert" =
          "exec ${pkgs.wayshot}/bin/wayshot --stdout | ${pkgs.satty}/bin/satty --filename - --fullscreen";

        "${modifier}+period" =
          "exec ${pkgs.swaynotificationcenter}/bin/swaync-client --hide-latest";

        # "Insert" =
        #   "exec ${pkgs.grim}/bin/grim -o $(swaymsg -t get_outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.focused) | .name') - | ${pkgs.satty}/bin/satty --filename - --fullscreen";
        # Screen recording
        # "${modifier}+Print" = "exec wayrecorder --notify screen";
        # "${modifier}+Shift+Print" = "exec wayrecorder --notify --input area";
        # "${modifier}+Alt+Print" = "exec wayrecorder --notify --input active";
        # "${modifier}+Shift+Alt+Print" =
        #   "exec wayrecorder --notify --input window";
        # "${modifier}+Ctrl+Print" =
        #   "exec wayrecorder --notify --clipboard --input screen";
        # "${modifier}+Ctrl+Shift+Print" =
        #   "exec wayrecorder --notify --clipboard --input area";
        # "${modifier}+Ctrl+Alt+Print" =
        #   "exec wayrecorder --notify --clipboard --input active";
        # "${modifier}+Ctrl+Shift+Alt+Print" =
        #   "exec wayrecorder --notify --clipboard --input window";

        # "Print+Shift" = "exec ${pkgs.flameshot}/bin/flameshot -c region";
        # "Print+Shift+Control" = "exec ${pkgs.flameshot}/bin/flameshot -c window";
        # I don't like this because ultimately I just keep switching to the wrong workspace
        # "alt+tab" = "workspace back_and_forth";
        # "${modifier}+period" = "exec makoctl dismiss";
        # "${modifier}+shift+period" = "exec makoctl dismiss -a";
        "${modifier}+z" = "exec swaylock";
        "${modifier}+Shift+z" = "exec ${pkgs.wlogout}/bin/wlogout";
        "XF86AudioMute" =
          "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && (wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo 0 > $XDG_RUNTIME_DIR/wob.sock) || wpctl get-volume @DEFAULT_AUDIO_SINK@ > $XDG_RUNTIME_DIR/wob.sock";
        "XF86AudioRaiseVolume" =
          "exec wpctl set-volume --limit 1.5 @DEFAULT_AUDIO_SINK@ 2%+ && wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed 's/[^0-9]//g' > $XDG_RUNTIME_DIR/wob.sock";
        "XF86AudioLowerVolume" =
          "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%- && wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed 's/[^0-9]//g' > $XDG_RUNTIME_DIR/wob.sock";

        # Toggle control center
        "${modifier}+Shift+n" =
          "exec ${pkgs.swaynotificationcenter}/bin/swaync-client --toggle-panel --skip-wait";
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
    # extraConfig = "exec ${pkgs.swaynotificationcenter}/bin/swaync";
  };
}
