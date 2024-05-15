{ pkgs, ... }:
{
  home.packages = with pkgs; [
    proxychains
    gg # for proxying commands
    nekoray
  ];
}
