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

  mpvBindings = {
    # speed
    "'" = "set speed 1.0";
    "]" = "add speed 0.1";
    "[" = "add speed -0.1";
    # move
    "h" = "seek -5";
    "l" = "seek 5";
    "H" = "seek -60";
    "L" = "seek 60";
    "k" = "add volume 2";
    "j" = "add volume -2";
    # zoom
    "-" = "add video-zoom -.25";
    "+" = "add video-zoom .25";
  };

  mpvConfig = {
    # profile = "gpu-hq";
    ytdl-format = "bestvideo+bestaudio";
    # cache-default = 4000000;
    speed = 2;
    sub-auto = "fuzzy";
    sub-visibility = "yes";
    audio-file-auto = "fuzzy";
    save-position-on-quit = "yes";
    osc = "no";

    gpu-context = "wayland";
    hwdec = "auto-safe";
    vo = "gpu";
    profile = "gpu-hq";
  };
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
    services.jellyfin-mpv-shim = {
      enable = true;
      mpvBindings = mpvBindings;
      mpvConfig = mpvConfig;
    };

    programs.mpv = {
      enable = true;
      # https://raw.githubusercontent.com/mpv-player/mpv/master/etc/input.conf
      bindings = mpvBindings;
      config = mpvConfig;
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
        mpv-slicing # cut with c
      ];
    };
  };
}
