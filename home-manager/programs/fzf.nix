{ pkgs, ... }: {
  programs.fzf = {
    enable = true;
    defaultCommand = "${pkgs.fd}/bin/fd --type f --hidden";

    changeDirWidgetCommand = "${pkgs.fd}/bin/fd --type d --hidden --exclude __pycache__";
    changeDirWidgetOptions = [ "--preview '${pkgs.tre-command}/bin/tre -C {} | head -200'" ];

    fileWidgetCommand = "${pkgs.fd}/bin/fd --hidden --exclude __pycache__";
    fileWidgetOptions = [ "--preview '${pkgs.bat}/bin/bat --color always {} 2> /dev/null || ${pkgs.tre-command}/bin/tre -C {}'" ];

    historyWidgetOptions = [ "--reverse" ];

    tmux.enableShellIntegration = false;
  };
}
