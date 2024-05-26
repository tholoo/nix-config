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
  name = "mpv";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "media"
      "video"
    ];
  };

  config = mkIf cfg.enable {
    programs.mpv = {
      enable = true;
      config = {
        # profile = "gpu-hq";
        ytdl-format = "bestvideo+bestaudio";
        # cache-default = 4000000;
      };
      scripts = with pkgs.mpvScripts; [
        mpris
        # Feature-rich minimalist proximity-based UI for MPV player
        seekTo
        thumbnail
        thumbfast
        mpvacious
        # Youtube
        sponsorblock
        quality-menu
      ];
    };
  };
}
