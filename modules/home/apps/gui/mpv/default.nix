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
      # https://raw.githubusercontent.com/mpv-player/mpv/master/etc/input.conf
      bindings = {
        # speed
        "z" = "set speed 1.0";
        "c" = "add speed 0.1";
        "x" = "add speed -0.1";
        # move
        "h" = "seek -5";
        "l" = "seek 5";
        "shift+h" = "seek -60";
        "shift+l" = "seek -60";
        "k" = "add volume 2";
        "j" = "add volume -2";
      };
      config = {
        # profile = "gpu-hq";
        ytdl-format = "bestvideo+bestaudio";
        # cache-default = 4000000;
        speed = 2;
        sub-auto = "fuzzy";
        sub-visibility = "yes";
        audio-file-auto = "fuzzy";
        save-position-on-quit = "yes";
      };
      scripts = with pkgs.mpvScripts; [
        mpris
        # Feature-rich minimalist proximity-based UI for MPV player
        seekTo
        thumbnail
        thumbfast
        mpvacious # for creating anki cards
        # Youtube
        sponsorblock
        quality-menu
      ];
    };
  };
}
