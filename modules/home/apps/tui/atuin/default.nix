{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "atuin";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
      "history"
    ];
  };

  config = mkIf cfg.enable {
    programs.${name} = {
      enable = true;
      flags = [ "--disable-up-arrow" ];
      settings = {
        search_mode = "skim";
        style = "compact";
        invert = true;
        show_preview = true;
        keymap_mode = "vim-insert";
        inline_height = 20;
        show_help = false;
        keymap_cursor = {
          vim_insert = "blink-bar";
          vim_normal = "steady-block";
        };
      };
    };
  };
}
