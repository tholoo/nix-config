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
  name = "vivaldi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "browser"
      "web"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # (vivaldi.override {
      # proprietaryCodecs = true;
      # enableWidevine = false;
      # })
      vivaldi
      vivaldi-ffmpeg-codecs
    ];
  };
}
