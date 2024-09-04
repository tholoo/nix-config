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
  name = "espanso";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "interactive"
    ];
  };

  config = mkIf cfg.enable {
    services.espanso = {
      enable = false;
      package = pkgs.espanso-wayland;
      configs = {
        default = {
          show_notification = false;
          search_shortcut = "ALT+SPACE";
          search_trigger = ";srch";
          # show_icon = false;
          keyboard_layout = {
            layout = "us";
          };
        };
      };
      matches = {
        base = {
          matches = [
            {
              trigger = ";now";
              replace = "{{currentdate}} {{currenttime}}";
            }
            {
              trigger = ";date";
              replace = "{{currentdate}}";
            }
            {
              trigger = ";time";
              replace = "{{currenttime}}";
            }
          ];
        };
        global_vars = {
          global_vars = [
            {
              name = "currentdate";
              type = "date";
              params = {
                format = "%Y/%m/%d";
              };
            }
            {
              name = "currenttime";
              type = "date";
              params = {
                format = "%R";
              };
            }
          ];
        };
      };
    };
  };
}
