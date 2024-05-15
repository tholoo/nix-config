{ pkgs, ... }:
{
  home.packages = with pkgs; [
    figlet # generate ascii art of strings
    grc # command colorizer
    # fetchers
    fastfetch
    onefetch
  ];
}
