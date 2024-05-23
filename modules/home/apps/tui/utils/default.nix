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
  name = "utils";
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
      ripgrep # recursively searches directories for a regex pattern
      jq # A lightweight and flexible command-line JSON processor
      yq-go # yaml processor https://github.com/mikefarah/yq
      watchexec # Run commands based on file change
      satty # Screen annotatiaon tool
      bottom # System monitor
      dust # a better du
      duf # a better df
      gping # ping but with a graph
      trashy # for deleting things to trash
      usql # universal sql cli tool
      xh # faster httpie
      asdf-vm # a runtime programming language version manager (like pyenv)
      yt-dlp # audio/video downloader
      inetutils # commands like telnet
      sd # better sed
    ];
  };
}
