{ pkgs, ... }:
{
  home.packages = with pkgs; [
    qpwgraph
    helvum
  ];
}
