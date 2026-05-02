{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "winbox";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "network"
    ];
  };

  config = mkIf cfg.enable {
    programs.winbox = {
      enable = true;
      openFirewall = true;
    };
  };
}
