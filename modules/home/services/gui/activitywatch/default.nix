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
        aw-watcher-afk = {
          package = pkgs.aw-watcher-afk;
          settings = {
            timeout = 300;
            poll_time = 2;
          };
        };
        aw-watcher-window = {
          package = pkgs.aw-watcher-window;
          settings = {
            poll_time = 1;
            exclude_title = true;
          };
        };
      };
    };
  };
}
