{ pkgs, ... }: {
  xsession = {
    enable = true;
    windowManager = {
      i3 = {
        enable = true;
        config = {
          modifier = "Mod4";
          terminal = "${pkgs.wezterm}/bin/wezterm";
          # switch to previous workspace by pressing this workspace's key again
          workspaceAutoBackAndForth = true;
          menu = "${pkgs.rofi}/bin/rofi -show drun";
          defaultWorkspace = "1";
          window = {
            hideEdgeBorders = "smart";
          };
        };
      };
    };
  };
}
