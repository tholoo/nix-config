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
  name = "tui-misc";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # essentials
      xdg-utils
      # gcc
      libgcc
      libgccjit
      clang

      # archives
      zip
      unzip
      p7zip

      glow # markdown previewer in terminal

      # clipboard
      wl-clipboard

      distrobox

      ffmpeg
    ];
  };
}
