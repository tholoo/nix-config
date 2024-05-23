{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "opengl";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "graphics"
    ];
  };

  config = mkIf cfg.enable {
    hardware = {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
      };
    };
  };
}
