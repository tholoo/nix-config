{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "wob";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "audio"
      "interactive"
    ];
  };

  config = mkIf cfg.enable {
    # progress bar
    services.wob = {
      enable = true;
      systemd = true;
      settings = {
        "" = {
          background_color = "000000";
          bar_color = "FFFFFF";
          # border_color = "FFFFFF";
          anchor = "bottom";
          margin = 30;

          overflow_background_color = "00000088";
          overflow_bar_color = "dd6359ff";
          overflow_border_color = "cd53495f";

          width = 400;
          output_mode = "focused";
          border_size = 2;
          bar_padding = 6;
        };
        "style.muted" = {
          background_color = "ADD8E6";
          bar_color = "0000FF";
        };
      };
    };
  };
}
