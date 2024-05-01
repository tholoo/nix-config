{
  config,
  pkgs,
  lib,
  options,
  self,
  ...
}:
{
  # Use sway desktop environment with Wayland display server
  home.packages = options.home.packages.default ++ (with pkgs; [ swaynotificationcenter ]);
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
      menu = "${lib.getExe pkgs.wofi} --show drun,run";
      gaps = {
        smartGaps = true;
        smartBorders = "on";
      };
      startup = [
        { command = "vivaldi"; }
        { command = "wezterm"; }
        { command = "exec ${lib.getExe' pkgs.swaynotificationcenter "swaync"}"; }
        # make copied data persist after closing the application
        { command = "exec ${lib.getExe pkgs.wl-clip-persist} --clipboard both"; }
        { command = "telegram-desktop"; }
        # { command = "systemctl --user restart waybar"; always = true; }
      ];
      assigns = {
        "1" = [ { app_id = "^org.wezfurlong.wezterm$"; } ];
        "2" = [
          { app_id = "^firefox$"; }
          { app_id = "vivaldi-stable"; }
        ];
        "3" = [ { app_id = "org.telegram.desktop"; } ];
      };
      bars = [
        {
          #   fonts.size = 15.0;
          command = "waybar";
          position = "bottom";
          # statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs";
        }
      ];
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
      keybindings = lib.mkOptionDefault (
        with pkgs;
        with lib;
        {
          # "Print" = "exec ${pkgs.shotman}/bin/shotman -c output";
          # "Print+Shift" = "exec ${pkgs.shotman}/bin/shotman -c region";
          # "Print+Shift+Control" = "exec ${pkgs.shotman}/bin/shotman -c window";
          # "Print" = ''exec --no-startup-id "${pkgs.flameshot}/bin/flameshot"'';
          "Print" = ''exec ${getExe wayshot} -s "$(${getExe slurp} -o -c '#ff0000ff')" --stdout | ${getExe satty} --filename - --fullscreen --initial-tool line'';

          "Insert" = "exec ${getExe wayshot} --stdout | ${getExe satty} --filename - --fullscreen --initial-tool brush";

          "${modifier}+period" = "exec ${getExe' swaynotificationcenter "swaync-client"} --hide-latest";

          "${modifier}+y" = "exec ${getExe cliphist} list | ${getExe wofi} --show dmenu | ${getExe cliphist} decode | ${getExe' wl-clipboard "wl-copy"}";
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
          "${modifier}+Shift+z" = "exec ${getExe wlogout}";
          "XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && (wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo 0 > $XDG_RUNTIME_DIR/wob.sock) || wpctl get-volume @DEFAULT_AUDIO_SINK@ > $XDG_RUNTIME_DIR/wob.sock";
          "XF86AudioRaiseVolume" = "exec wpctl set-volume --limit 1.5 @DEFAULT_AUDIO_SINK@ 2%+ && wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed 's/[^0-9]//g' > $XDG_RUNTIME_DIR/wob.sock";
          "XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%- && wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed 's/[^0-9]//g' > $XDG_RUNTIME_DIR/wob.sock";

          # Toggle control center
          "${modifier}+Shift+n" = "exec ${getExe' swaynotificationcenter "swaync-client"} --toggle-panel --skip-wait";

          # Work with Persian layout
          "${modifier}+Farsi_1" = "workspace number 1";
          "${modifier}+Farsi_2" = "workspace number 2";
          "${modifier}+Farsi_3" = "workspace number 3";
          "${modifier}+Farsi_4" = "workspace number 4";
          "${modifier}+Farsi_5" = "workspace number 5";
          "${modifier}+Farsi_6" = "workspace number 6";
          "${modifier}+Farsi_7" = "workspace number 7";
          "${modifier}+Farsi_8" = "workspace number 8";
          "${modifier}+Farsi_9" = "workspace number 9";
          "${modifier}+Farsi_0" = "workspace number 10";
        }
      );

      keycodebindings = {
        "${modifier}+shift+24" = "kill";
      };

      output = {
        "*" = {
          bg = "${../../../resources/wallpapers/wallhaven-fields-858z32.png} fill";
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
