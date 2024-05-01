{ pkgs, ... }:
{
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
      uosc
      seekTo
      thumbnail
      thumbfast
      mpvacious
      # Youtube
      sponsorblock
      quality-menu
    ];
  };
}
