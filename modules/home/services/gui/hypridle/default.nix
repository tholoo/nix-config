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
  name = "hypridle";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "hypr"
      "gui"
      "service"
    ];
  };

  config = mkIf cfg.enable {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on"; # wake screens after resume
          ignore_dbus_inhibit = false; # honor app inhibitors; set true to force
          lock_cmd = "hyprlock";
        };

        listener = [
          # 1) Lock at 15 min
          {
            timeout = 900;
            on-timeout = "hyprlock";
          }

          # 2) Turn displays off ~30s after lock (only if actually locked)
          {
            timeout = 930; # 900 + 30
            on-timeout = "pidof hyprlock && hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }

          # 3) Suspend 10 min after lock (only if still locked)
          {
            timeout = 1500; # 900 + 600
            on-timeout = "pidof hyprlock && systemctl suspend";
          }
        ];
      };
    };
  };
}
