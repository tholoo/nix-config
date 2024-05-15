{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # it provides the command `nom` works just like `nix`
    # with more detailed log output
    nix-output-monitor
    nix-prefetch-github
    nix-tree
    nh
    devenv
    manix
    nurl
  ];
}
