{ pkgs, ... }:
{
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
  ];
}
