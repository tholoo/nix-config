{
  config,
  lib,
  pkgs,
  ...
}:
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
      enable = config.mine.terminal.emulator == name;
      package = pkgs.mine.ghostty-rtl;
      installBatSyntax = true;
      installVimSyntax = true;
      settings = {
        confirm-close-surface = false;
        # Agents send native desktop notifications themselves. Do not duplicate
        # them through terminal escape sequences or shell command completion.
        desktop-notifications = false;
        notify-on-command-finish = "never";
        # Keep Persian/Arabic joining intact as the cursor moves through a word.
        font-shaping-break = "no-cursor";
        # theme and font managed by stylix
        font-size = 12.5;
      };
    };
  };
}
