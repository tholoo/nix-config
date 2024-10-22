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
  name = "zellij";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "tui-interactive"
      "multiplexer"
    ];
  };

  config = mkIf cfg.enable {
    programs.zellij = {
      enable = true;
    };
    xdg.configFile."zellij/config.kdl".source = ./config.kdl;
  };
}
