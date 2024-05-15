{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # (vivaldi.override {
    # proprietaryCodecs = true;
    # enableWidevine = false;
    # })
    vivaldi
    vivaldi-ffmpeg-codecs
  ];
}
