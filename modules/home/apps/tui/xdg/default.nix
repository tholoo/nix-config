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
  terminal = config.mine.terminal;
in
{
  options.mine.${name} = mkEnable config { tags = [ "tui" ]; };

  config = mkIf cfg.enable {
    xdg.configFile."xdg-desktop-portal-termfilechooser/config" = {
      enable = true;
      force = true;
      text = ''
        [filechooser]
        cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
        default_dir=${config.home.homeDirectory}/Downloads
        env=TERMCMD=${terminal.chooserCommand}
        open_mode=suggested
        save_mode=suggested
      '';
    };

    xdg.terminal-exec = {
      enable = true;
      settings = {
        default = [
          terminal.desktopId
        ];
      };
    };
    home.preferXdgDirectories = true;

    xdg = {
      enable = true;
      mimeApps = {
        enable = true;
        defaultApplications = {
          "application/pdf" = "${pkgs.zathura}/share/application/org.pwmt.zathura.desktop";

          "text/html" = "zen-beta.desktop";
          "x-scheme-handler/http" = "zen-beta.desktop";
          "x-scheme-handler/https" = "zen-beta.desktop";
          "x-scheme-handler/about" = "zen-beta.desktop";
          "x-scheme-handler/unknown" = "zen-beta.desktop";
        };
      };
    };
  };
}
