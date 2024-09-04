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

  # make commands ranging from 0 to 9 for both english and persian
  # e.g. modifier+1 = exec 'something 1'
  mkNumbers =
    key: cmd:
    let
      numsEnglish = map (num: builtins.toString num) (lib.range 0 9);
      numsPersian = lib.mergeAttrsList (map (num: { "${num}" = "Farsi_${num}"; }) numsEnglish);

      mapEnglish = map (num: { "${key}+${num}" = "exec '${cmd} ${num}'"; }) numsEnglish;
      mapPersian = lib.mapAttrsToList (numEn: numFa: {
        "${key}+${numFa}" = "exec '${cmd} ${numEn}'";
      }) numsPersian;
    in
    lib.mergeAttrsList (mapEnglish ++ mapPersian);
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
      enable = false;
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
          # { command = "vivaldi"; }
          # { command = "wezterm"; }
          # make copied data persist after closing the application
          { command = "exec ${lib.getExe pkgs.wl-clip-persist} --clipboard both"; }
          {
            command = "${lib.getExe' pkgs.systemd "systemctl"} --user reload-or-restart kanshi.service";
            always = true;
          }
          # { command = "telegram-desktop"; }
          # { command = "systemctl --user restart waybar"; always = true; }
        ];
        # assigns = {
        # "11" = [ { app_id = "^org.wezfurlong.wezterm$"; } ];
        # "12" = [
        #   { app_id = "^firefox$"; }
        #   { app_id = "vivaldi-stable"; }
        # ];
        # "13" = [ { app_id = "org.telegram.desktop"; } ];
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
          "type:touchpad" = {
            click_method = "clickfinger";
            drag = "enabled";
            dwt = "enabled";
            # events = "disabled_on_external_mouse";
            middle_emulation = "enabled";
            accel_profile = "flat"; # disable mouse acceleration
            pointer_accel = "0.8";
            scroll_method = "two_finger";
            tap = "enabled";
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
            # Move focused container to next output
            "${modifier}+o" = "exec '${lib.getExe pkgs.swaysome} next-output'";
            # Move focused container to previous output
            "${modifier}+Shift+o" = "exec '${lib.getExe pkgs.swaysome} prev-output'";
            # Move focused workspace group to next output
            "${modifier}+Alt+o" = "exec '${lib.getExe pkgs.swaysome} workspace-group-next-output'";
            # Move focused workspace group to previous output
            "${modifier}+Alt+Shift+o" = "exec '${lib.getExe pkgs.swaysome} workspace-group-prev-output'";
          }
          # Work with Persian layout
          // mkNumbers modifier "${lib.getExe pkgs.swaysome} focus"
          # Move containers between workspaces
          // mkNumbers "${modifier}+Shift" "${lib.getExe pkgs.swaysome} move"
          # Focus workspace groups
          // mkNumbers "${modifier}+Alt" "${lib.getExe pkgs.swaysome} focus-group"
          # Move containers to other workspace groups
          // mkNumbers "${modifier}+Alt+Shift" "${lib.getExe pkgs.swaysome} move-to-group"

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

      extraConfig = ''
        # Allow switching between workspaces with left and right swipes
        bindgesture swipe:right workspace next
        bindgesture swipe:left workspace prev
            
        # Allow container movements by pinching them
        bindgesture pinch:inward+up move up
        bindgesture pinch:inward+down move down
        bindgesture pinch:inward+left move left
        bindgesture pinch:inward+right move right
      '';
    };
  };
}
