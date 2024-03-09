{ pkgs, ... }: {
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      # Screen capture on wlroots based wayland compositors
      wlrobs
      # Audio device and application capture for OBS Studio using PipeWire
      obs-pipewire-audio-capture
    ];
  };
}
