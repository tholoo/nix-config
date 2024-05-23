{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "keyd";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "input"
    ];
  };

  config = mkIf cfg.enable {
    services.keyd = {
      enable = true;
      keyboards = {
        default = {
          settings = {
            main = {
              # https://github.com/rvaiya/keyd/blob/2338f11b1ddd81eaddd957de720a3b4279222da0/t/keys.py
              capslock = "esc";
              # leftbrace = "overload(meta, leftbrace)";
              leftbrace = "lettermod(meta, leftbrace, 100, 150)";
              # leftbrace = "overloadi(leftbrace, overloadt2(meta, leftbrace, 150), 100)";
              # meta = "oneshot(meta)";
              # rightalt = "overload(meta, rightalt)";
              rightalt = "layer(nav)";
              # backtick = "layer(layout_switch)";
            };
            # TODO: Make layout layers
            # layout_switch = {
            # "1" = "setlayout(qwerty)";
            # "2" = "setlayout(dvorak)";
            # };
            nav = {
              h = "left";
              j = "down";
              k = "up";
              l = "right";
            };
          };
        };
      };
    };
  };
}
