{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "kdeconnect";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "interactive"
      "phone"
    ];
  };

  config = mkIf cfg.enable {
    # connect android to linux
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
  };
}
