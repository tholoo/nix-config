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
  name = "proxy";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "proxy"
      "vpn"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      gg # for proxying commands
      nekoray
    ];
  };
}
