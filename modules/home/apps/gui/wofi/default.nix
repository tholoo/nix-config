{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "wofi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "gui-bar"
      "wayland"
    ];
  };

  config = mkIf cfg.enable {
    # TODO: switch to fuzzel
    programs.wofi = {
      enable = true;
      style = builtins.readFile ./style.css;
      settings = {
        allow_images = true;
        allow_markup = true;
        key_backward = "Ctrl-p";
        key_forward = "Ctrl-n";
        matching = "fuzzy";
      };
    };
  };
}
