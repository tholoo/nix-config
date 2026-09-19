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
  name = "atuin";
  nushellConfig =
    pkgs.runCommand "atuin-nushell-config.nu"
      {
        nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
      }
      ''
        ${lib.getExe config.programs.atuin.package} init nu ${lib.escapeShellArgs config.programs.atuin.flags} > "$out"
      '';
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
    programs = {
      ${name} = {
        enable = true;
        enableNushellIntegration = false;
        flags = [ "--disable-up-arrow" ];
        settings = {
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

      # Nushell merges nonempty keybinding assignments. Clear before restoring
      # the other bindings so the built-in Ctrl-R menu is actually removed.
      nushell.extraConfig = lib.mkOrder 2000 ''
        let atuin_keybindings = ($env.config.keybindings | where name not-in [history_menu atuin])
        $env.config.keybindings = []
        $env.config.keybindings = $atuin_keybindings
        source-env ${nushellConfig}
      '';
    };
  };
}
