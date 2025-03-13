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
  name = "yt-dlp";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-utils"
    ];
  };

  config = mkIf cfg.enable {
    programs.yt-dlp = {
      enable = true;
      settings = {
        embed-thumbnail = true;
        # proxy = "http://127.0.0.1:20171";
      };
    };
  };
}
