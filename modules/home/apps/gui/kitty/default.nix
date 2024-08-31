{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "kitty";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "terminal"
    ];
  };

  config = mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      settings = {
        enable_audio_bell = false;
      };
    };
  };
}
