{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "wireshark";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "gui-misc"
      "network"
    ];
  };

  config = mkIf cfg.enable {
    programs.wireshark = {
      enable = true;
    };
  };
}
