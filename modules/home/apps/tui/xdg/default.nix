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
  name = "xdg";
in
{
  options.mine.${name} = mkEnable config { tags = [ "tui" ]; };

  config = mkIf cfg.enable {
    xdg = {
      enable = true;
      mimeApps.defaultApplications = {
        "application/pdf" = "${pkgs.zathura}/share/application/org.pwmt.zathura.desktop";
      };
    };
  };
}
