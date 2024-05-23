{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "cliphist";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "clipboard"
    ];
  };

  config = mkIf cfg.enable {
    # clipboard manager for wayland
    services.cliphist.enable = true;
  };
}
