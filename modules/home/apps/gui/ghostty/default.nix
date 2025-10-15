{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "ghostty";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "terminal"
    ];
  };

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      installBatSyntax = true;
      installVimSyntax = true;
      settings = {
        confirm-close-surface = false;
        theme = "Deep";
        font-family = "JetBrainsMono Nerd Font";
        font-size = 12.5;
      };
    };
  };
}
