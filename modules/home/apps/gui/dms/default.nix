{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "dms";
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

    programs.dank-material-shell = {
      enable = true;
      # Use the Hydra-built nixpkgs package rather than rebuilding the package
      # exposed by the upstream flake.
      package = pkgs.dms-shell;
      systemd.enable = true;

      # Stylix owns the shared palette and wallpaper. Avoid installing matugen
      # or letting DMS retheme the rest of the desktop independently.
      enableDynamicTheming = false;
      enableCalendarEvents = false;

      settings = {
        clockFormat = "24h";
        showSeconds = true;
        fontScale = 0.9;
        weatherEnabled = false;
        updaterCheckOnStart = false;

        # Preserve the remapped Caps Lock behavior and the right-side OSD.
        osdCapsLockEnabled = false;
        osdPosition = 7; # RightCenter

        barConfigs = [
          {
            id = "default";
            name = "Main Bar";
            enabled = true;
            position = 1; # Bottom
            screenPreferences = [ "all" ];
            showOnLastDisplay = true;
            leftWidgets = [
              "launcherButton"
              "workspaceSwitcher"
              "focusedWindow"
            ];
            centerWidgets = [ "music" ];
            rightWidgets = [
              "systemTray"
              "cpuUsage"
              "memUsage"
              "clock"
              "notificationButton"
              "battery"
              "controlCenterButton"
            ];
            spacing = 0;
            innerPadding = 4;
            bottomGap = 0;
            transparency = 1.0;
            widgetTransparency = 1.0;
            squareCorners = true;
          }
        ];
      };
    };

    # DMS 1.5 hard-codes its changelog prompt on and suppresses it after this
    # per-version marker exists. Manage it so fresh generations remain quiet.
    xdg.configFile."DankMaterialShell/.changelog-1.5".text = "";
  };
}
