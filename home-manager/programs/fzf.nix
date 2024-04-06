{ pkgs, lib, ... }: {
  # TODO: see ~/.config/fish/config.fish 
  programs.fzf = let
    excludes = lib.fold (el: c: "${c} --exclude ${el}") "" [
      "__pycache__"
      ".venv"
      "venv"
      ".git"
      ".direnv"
    ];
    tre_cmd =
      "${pkgs.tre-command}/bin/tre --color always {} --limit 5 --all ${excludes}";
    bat_cmd = "${pkgs.bat}/bin/bat --color always {}";
    fd_cmd = "${pkgs.fd}/bin/fd --hidden --follow ${excludes}";
  in {
    enable = true;
    defaultCommand = "${fd_cmd} --type f";

    changeDirWidgetCommand = "${fd_cmd} --type d";
    # changeDirWidgetOptions = [ "--preview '${tre_cmd} | head -100'" ];
    #
    fileWidgetCommand = fd_cmd;
    # fileWidgetOptions =
    #   [ "--preview '${bat_cmd} 2> /dev/null || ${tre_cmd} | head -100'" ];
    #
    # historyWidgetOptions = [ "--reverse" ];

    tmux.enableShellIntegration = false;
  };
}
