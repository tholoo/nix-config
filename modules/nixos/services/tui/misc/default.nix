{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "tui-misc";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    services = {
      gvfs.enable = true;
      gnome.gnome-keyring.enable = true;
    };
  };
}
