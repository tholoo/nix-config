# default port is 5600
{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "activitywatch";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "monitor"
    ];
  };

  config = mkIf cfg.enable {
    services.activitywatch = {
      enable = true;
      package = pkgs.aw-server-rust;
      watchers = {
        awatcher = {
          package = pkgs.awatcher;
        };
      };
    };

    # The stock watchers require X11. awatcher supports both window and idle
    # tracking natively on Hyprland.
    xdg.configFile."awatcher/config.toml".source = (pkgs.formats.toml { }).generate "awatcher-config.toml" {
      server = {
        host = "127.0.0.1";
        port = 5600;
      };
      awatcher = {
        idle-timeout-seconds = 300;
        poll-time-idle-seconds = 2;
        poll-time-window-seconds = 1;
      };
    };

    # Start after Hyprland has imported DISPLAY/WAYLAND_DISPLAY into the user
    # manager, and stop the tracker when the graphical session ends.
    systemd.user.targets.activitywatch = {
      Unit = {
        After = lib.mkForce [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
    };
  };
}
