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
  name = "greetd";

in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "login"
    ];
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = lib.concatStringsSep " " [
            "${pkgs.tuigreet}/bin/tuigreet"
            "--time"
            "--remember"
            "--remember-session"
            "--asterisks"
            "--user-menu"
            # Keep system/service accounts (including Nix's nixbld workers) out
            # of the graphical user picker while retaining normal users.
            "--user-menu-min-uid 1000"
            "--user-menu-max-uid 29999"
            "--cmd Hyprland"
          ];
          user = "tholo";
        };
      };
    };

    environment.etc."greetd/environments".text = ''
      Hyprland
      sway
    '';

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };
  };
}
