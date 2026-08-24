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
  nushellConfig = pkgs.runCommand "atuin-nushell-config-helix.nu" {
    nativeBuildInputs = [ pkgs.writableTmpDirAsHomeHook ];
  } ''
    ${lib.getExe config.programs.atuin.package} init nu ${lib.escapeShellArgs config.programs.atuin.flags} > "$out"
    substituteInPlace "$out" \
      --replace-fail \
      'name: atuin' \
      'name: history_menu' \
      --replace-fail \
      'mode: [emacs, vi_normal, vi_insert]' \
      'mode: [emacs, vi_normal, vi_insert, helix_normal, helix_select, helix_insert]'
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

      # TODO: Remove this workaround once Atuin's Nushell init supports Helix
      # modes and replaces Nushell 0.115's history_menu binding by name.
      # Atuin 18.19 uses a separate binding name and only covers Emacs and Vi.
      # Patch its generated binding to replace Nushell's built-in history menu
      # and cover Helix, so Atuin owns Ctrl-R in every configured editor mode.
      nushell.extraConfig = lib.mkOrder 2000 ''
        source-env ${nushellConfig}
      '';
    };
  };
}
