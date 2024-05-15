{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # learning
    tldr
    cht-sh
    obsidian
    calibre
  ];
}
