{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "kanata";
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
    services.kanata = {
      enable = true;

      keyboards.default = {
        extraDefCfg = ''
          process-unmapped-keys yes
          allow-hardware-repeat false
        '';

        config = ''
          (defsrc)

          (defalias
            ;; Match keyd's lettermod timing: tap for the bracket, hold for
            ;; the modifier, and resolve to hold as soon as another key is
            ;; pressed. The f24 wrapper avoids Kanata's documented Linux
            ;; antecedent-key repeat issue with tap-hold actions.
            left-bracket  (multi f24 (tap-hold-press 100 150 [ lmet))
            right-bracket (multi f24 (tap-hold-press 100 150 ] lalt))
            nav           (layer-while-held nav)
          )

          (deflayermap (base)
            caps esc
            [    @left-bracket
            ]    @right-bracket
            ralt @nav
          )

          (deflayermap (nav)
            h left
            j down
            k up
            l right
          )
        '';
      };
    };
  };
}
