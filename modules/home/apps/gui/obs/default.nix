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
  name = "obs";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "media"
      "video"
      "stream"
    ];
  };

  config = mkIf cfg.enable {
    programs.obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        # Screen capture on wlroots based wayland compositors
        wlrobs
        # Audio device and application capture for OBS Studio using PipeWire
        obs-pipewire-audio-capture
      ];
    };
  };
}
