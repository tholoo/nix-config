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
  name = "irc";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      weechat
    ];
  };
}
