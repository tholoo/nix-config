{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "sway";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "window-manager"
      "wayland"
    ];
  };

  config = mkIf cfg.enable {
    services.swaync = {
      enable = true;
    };

    programs.swaylock = {
      enable = true;
      settings = {
        image = "${inputs.self}/resources/wallpapers/wallhaven-car-swamp.png";
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
        # defaultWorkspace = "1";
        menu = "${lib.getExe pkgs.wofi} --show drun,run";
        gaps = {
          smartGaps = true;
          smartBorders = "on";
        };
        startup = [
          { command = "'${lib.getExe pkgs.swaysome} init 1'"; }
          { command = "vivaldi"; }
          { command = "wezterm"; }
          # make copied data persist after closing the application
          { command = "exec ${lib.getExe pkgs.wl-clip-persist} --clipboard both"; }
          { command = "telegram-desktop"; }
          # { command = "systemctl --user restart waybar"; always = true; }
        ];
        # assigns = {
        #   "1" = [ { app_id = "^org.wezfurlong.wezterm$"; } ];
        #   "2" = [
        #     { app_id = "^firefox$"; }
        #     { app_id = "vivaldi-stable"; }
        #   ];
        #   "3" = [ { app_id = "org.telegram.desktop"; } ];
        # };
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
            "${modifier}+Farsi_1" = "exec '${lib.getExe pkgs.swaysome} focus 1'";
            "${modifier}+Farsi_2" = "exec '${lib.getExe pkgs.swaysome} focus 2'";
            "${modifier}+Farsi_3" = "exec '${lib.getExe pkgs.swaysome} focus 3'";
            "${modifier}+Farsi_4" = "exec '${lib.getExe pkgs.swaysome} focus 4'";
            "${modifier}+Farsi_5" = "exec '${lib.getExe pkgs.swaysome} focus 5'";
            "${modifier}+Farsi_6" = "exec '${lib.getExe pkgs.swaysome} focus 6'";
            "${modifier}+Farsi_7" = "exec '${lib.getExe pkgs.swaysome} focus 7'";
            "${modifier}+Farsi_8" = "exec '${lib.getExe pkgs.swaysome} focus 8'";
            "${modifier}+Farsi_9" = "exec '${lib.getExe pkgs.swaysome} focus 9'";
            "${modifier}+Farsi_0" = "exec '${lib.getExe pkgs.swaysome} focus 0'";

            # Change focus between workspaces
            "${modifier}+1" = "exec '${lib.getExe pkgs.swaysome} focus 1'";
            "${modifier}+2" = "exec '${lib.getExe pkgs.swaysome} focus 2'";
            "${modifier}+3" = "exec '${lib.getExe pkgs.swaysome} focus 3'";
            "${modifier}+4" = "exec '${lib.getExe pkgs.swaysome} focus 4'";
            "${modifier}+5" = "exec '${lib.getExe pkgs.swaysome} focus 5'";
            "${modifier}+6" = "exec '${lib.getExe pkgs.swaysome} focus 6'";
            "${modifier}+7" = "exec '${lib.getExe pkgs.swaysome} focus 7'";
            "${modifier}+8" = "exec '${lib.getExe pkgs.swaysome} focus 8'";
            "${modifier}+9" = "exec '${lib.getExe pkgs.swaysome} focus 9'";
            "${modifier}+0" = "exec '${lib.getExe pkgs.swaysome} focus 0'";
            # Move containers between workspaces
            "${modifier}+Shift+1" = "exec '${lib.getExe pkgs.swaysome} move 1'";
            "${modifier}+Shift+2" = "exec '${lib.getExe pkgs.swaysome} move 2'";
            "${modifier}+Shift+3" = "exec '${lib.getExe pkgs.swaysome} move 3'";
            "${modifier}+Shift+4" = "exec '${lib.getExe pkgs.swaysome} move 4'";
            "${modifier}+Shift+5" = "exec '${lib.getExe pkgs.swaysome} move 5'";
            "${modifier}+Shift+6" = "exec '${lib.getExe pkgs.swaysome} move 6'";
            "${modifier}+Shift+7" = "exec '${lib.getExe pkgs.swaysome} move 7'";
            "${modifier}+Shift+8" = "exec '${lib.getExe pkgs.swaysome} move 8'";
            "${modifier}+Shift+9" = "exec '${lib.getExe pkgs.swaysome} move 9'";
            "${modifier}+Shift+0" = "exec '${lib.getExe pkgs.swaysome} move 0'";
            # Focus workspace groups
            "${modifier}+Alt+1" = "exec '${lib.getExe pkgs.swaysome} focus-group 1'";
            "${modifier}+Alt+2" = "exec '${lib.getExe pkgs.swaysome} focus-group 2'";
            "${modifier}+Alt+3" = "exec '${lib.getExe pkgs.swaysome} focus-group 3'";
            "${modifier}+Alt+4" = "exec '${lib.getExe pkgs.swaysome} focus-group 4'";
            "${modifier}+Alt+5" = "exec '${lib.getExe pkgs.swaysome} focus-group 5'";
            "${modifier}+Alt+6" = "exec '${lib.getExe pkgs.swaysome} focus-group 6'";
            "${modifier}+Alt+7" = "exec '${lib.getExe pkgs.swaysome} focus-group 7'";
            "${modifier}+Alt+8" = "exec '${lib.getExe pkgs.swaysome} focus-group 8'";
            "${modifier}+Alt+9" = "exec '${lib.getExe pkgs.swaysome} focus-group 9'";
            "${modifier}+Alt+0" = "exec '${lib.getExe pkgs.swaysome} focus-group 0'";
            # Move containers to other workspace groups
            "${modifier}+Alt+Shift+1" = "exec '${lib.getExe pkgs.swaysome} move-to-group 1'";
            "${modifier}+Alt+Shift+2" = "exec '${lib.getExe pkgs.swaysome} move-to-group 2'";
            "${modifier}+Alt+Shift+3" = "exec '${lib.getExe pkgs.swaysome} move-to-group 3'";
            "${modifier}+Alt+Shift+4" = "exec '${lib.getExe pkgs.swaysome} move-to-group 4'";
            "${modifier}+Alt+Shift+5" = "exec '${lib.getExe pkgs.swaysome} move-to-group 5'";
            "${modifier}+Alt+Shift+6" = "exec '${lib.getExe pkgs.swaysome} move-to-group 6'";
            "${modifier}+Alt+Shift+7" = "exec '${lib.getExe pkgs.swaysome} move-to-group 7'";
            "${modifier}+Alt+Shift+8" = "exec '${lib.getExe pkgs.swaysome} move-to-group 8'";
            "${modifier}+Alt+Shift+9" = "exec '${lib.getExe pkgs.swaysome} move-to-group 9'";
            "${modifier}+Alt+Shift+0" = "exec '${lib.getExe pkgs.swaysome} move-to-group 0'";
            # Move focused container to next output
            "${modifier}+o" = "exec '${lib.getExe pkgs.swaysome} next-output'";
            # Move focused container to previous output
            "${modifier}+Shift+o" = "exec '${lib.getExe pkgs.swaysome} prev-output'";
            # Move focused workspace group to next output
            "${modifier}+Alt+o" = "exec '${lib.getExe pkgs.swaysome} workspace-group-next-output'";
            # Move focused workspace group to previous output
            "${modifier}+Alt+Shift+o" = "exec '${lib.getExe pkgs.swaysome} workspace-group-prev-output'";
          }
        );

        keycodebindings = {
          "${modifier}+shift+24" = "kill";
        };

        output = {
          "*" = {
            bg = "${inputs.self}/resources/wallpapers/wallhaven-fields-858z32.png fill";
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
  };
}
