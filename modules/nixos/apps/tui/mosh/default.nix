{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "mosh";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "ssh"
    ];
  };

  config = mkIf cfg.enable {
    programs.mosh = {
      enable = true;
      withUtempter = true;
      openFirewall = true;
    };
  };
}
