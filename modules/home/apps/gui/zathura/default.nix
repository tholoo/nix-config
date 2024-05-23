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
  name = "zathura";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "media"
      "pdf"
      "book"
    ];
  };

  config = mkIf cfg.enable {
    programs.zathura = {
      enable = true;
      options = {
        statusbar-h-padding = 0;
        statusbar-v-padding = 0;
        page-padding = 1;
        selection-clipboard = "clipboard";
      };
      mappings = {
        u = "scroll half-up";
        d = "scroll half-down";
        D = "toggle_page_mode";
        r = "reload";
        R = "rotate";
      };
    };
  };
}
