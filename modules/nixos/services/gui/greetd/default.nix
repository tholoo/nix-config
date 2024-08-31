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
          command = ''
            ${pkgs.greetd.tuigreet}/bin/tuigreet \
              --time \
              --remember \
              --remember-session \
              --asterisks \
              --user-menu \
              --cmd Hyprland
          '';
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
      TTYHangup = true;
      TTYVTDisallocate = true;
    };
  };
}
