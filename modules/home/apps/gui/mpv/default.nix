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

    # French study workflow
    "TAB" = "cycle secondary-sub-visibility";
    "p" = "script-message-to sub_pause toggle";
    "r" = "script-message-to sub_pause replay";
    "Ctrl+e" = "script-binding mpvacious-export-note";
    "Ctrl+v" = "script-binding mpvacious-copy-sub-to-clipboard";
    "Ctrl+m" = "script-binding mpvacious-menu-open";
    "Ctrl+d" = "script-message-to frmine enrich";
    "Alt+w" = "script-message-to frmine cycle";
    "P" = "script-message-to frmine study-toggle";
    "R" = "script-message-to frmine read-sentence";
    "Ctrl+L" = "script-message-to frmine lookup-type";
    "Ctrl+k" = "script-message-to frmine mark-known";
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

    # French study: prefer French as primary, English as secondary. mpv renders
    # the secondary track at the top of the screen by default, primary at the
    # bottom — they don't overlap. Tab toggles the secondary's visibility.
    slang = "fr,fra,fre,french";
    alang = "fr,fra,fre,french";
    secondary-sid = "auto";
    secondary-sub-visibility = "no";
    # Don't restore sub track choices on resume — let `slang` pick fresh each
    # time, otherwise an old "English primary" selection sticks forever.
    watch-later-options-remove = "sid,secondary-sid";
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

    # frmine.lua's lookup-only path uses espeak-ng for instant TTS.
    home.packages = [ pkgs.espeak-ng ];

    # Custom mpv Lua scripts live in the french-learning repo so the test
    # suite can lint them and the field-name contract with note-type.json is
    # testable from one place. Out-of-store symlinks let edits go live at the
    # next mpv launch without a home-manager rebuild — matches how
    # frdict/server.py is consumed by the systemd unit.
    xdg.configFile."mpv/scripts/sub-pause.lua".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/projects/french-learning/mpv/sub-pause.lua";
    xdg.configFile."mpv/scripts/frmine.lua".source =
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/projects/french-learning/mpv/frmine.lua";
  };
}
