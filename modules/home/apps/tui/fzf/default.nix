{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "fzf";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    # TODO: see ~/.config/fish/config.fish
    programs.fzf =
      let
        excludes = lib.foldr (el: c: "${c} --exclude ${el}") "" [
          "__pycache__"
          ".venv"
          "venv"
          ".git"
          ".direnv"
        ];
        tre_cmd = "${lib.getExe pkgs.tre-command} --color always {} --limit 5 --all ${excludes}";
        bat_cmd = "${lib.getExe pkgs.bat} --color always {}";
        fd_cmd = "${lib.getExe pkgs.fd} --hidden --color always --follow ${excludes} . \\$dir";
      in
      {
        enable = true;
        defaultCommand = "${fd_cmd} --type f";

        # changeDirWidgetCommand = "${fd_cmd} --type d";
        # changeDirWidgetOptions = [ "--preview '${tre_cmd} | head -100'" ];

        fileWidgetCommand = fd_cmd;
        fileWidgetOptions = [ "--ansi --preview '${bat_cmd} 2> /dev/null || ${tre_cmd} | head -100'" ];

        historyWidgetOptions = [ "--reverse" ];

        tmux.enableShellIntegration = false;
      };
  };
}
