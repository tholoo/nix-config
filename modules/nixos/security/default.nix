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
  name = "security";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    security = {
      polkit.enable = true;
      rtkit.enable = true;
      pam.services.swaylock = {
        text = "auth include login";
      };
      pam.services.hyprlock = { };
      wrappers.bwrap = {
        owner = "root";
        group = "root";
        source = "${pkgs.bubblewrap}/bin/bwrap";
        setuid = true;
      };
    };

    boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;
  };
}
